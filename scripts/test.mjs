import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const useBash = process.platform !== 'win32' || process.argv.includes('--bash');
const templateDir = join(repoRoot, 'template', '.opencode');
const opencodePath = join(templateDir, 'opencode.jsonc');
const slimPath = join(templateDir, 'oh-my-opencode-slim.jsonc');
const templateEntries = [
  'opencode.jsonc',
  'oh-my-opencode-slim.jsonc',
  'opencode.env',
  'oh-my-opencode-slim',
  'skills',
];

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function assertTemplate(configDir, models) {
  const opencode = readJson(join(configDir, 'opencode.jsonc'));
  const slim = readJson(join(configDir, 'oh-my-opencode-slim.jsonc'));
  const preset = slim.presets['generic-openai'];
  const council = slim.council.presets['generic-review-board'];

  assert.equal(opencode.$schema, 'https://opencode.ai/config.json');
  assert.deepEqual(opencode.plugin, ['oh-my-opencode-slim@2.2.17']);
  assert.equal(opencode.model, models.balanced);
  assert.equal(opencode.small_model, models.utility);
  assert.equal(opencode.subagent_depth, 1);
  for (const [name, model, variant] of [
    ['build', models.primary, 'medium'],
    ['plan', models.primary, 'high'],
    ['general', models.balanced, 'medium'],
    ['explore', models.utility, 'low'],
    ['title', models.utility, 'none'],
    ['summary', models.balanced, 'medium'],
    ['compaction', models.balanced, 'medium'],
  ]) {
    assert.equal(opencode.agent[name].model, model, `${name} model`);
    assert.equal(opencode.agent[name].variant, variant, `${name} effort`);
  }
  assert.equal(opencode.permission.websearch, 'deny');
  assert.equal(opencode.agent.librarian.permission.websearch, 'allow');
  assert.equal(opencode.permission.read['**/.env'], 'ask');
  assert.equal(opencode.permission.edit['**/.env'], 'deny');
  assert.equal(opencode.permission.edit['*'], undefined);
  assert.equal(opencode.permission.bash['*'], 'ask');
  assert.equal(opencode.permission.bash['git push *'], 'ask');
  assert.equal(opencode.permission.bash['terraform apply *'], 'ask');

  const nonDelegatingAgents = [
    'build',
    'general',
    'explore',
    'explorer',
    'librarian',
    'oracle',
    'fixer',
    'designer',
    'observer',
    'code-reviewer',
    'repo-architect',
    'test-writer',
    'security-reviewer',
  ];
  const taskControls = [
    'task',
    'task_status',
    'task_result',
    'task_message',
    'task_cancel',
    'task_revive',
    'wait_for_user',
  ];
  for (const agentName of nonDelegatingAgents) {
    for (const toolName of taskControls) {
      assert.equal(
        opencode.agent[agentName].permission[toolName],
        'deny',
        `${agentName} must deny ${toolName}`,
      );
    }
  }
  assert.deepEqual(opencode.agent.plan.permission.task, {
    '*': 'deny',
    explorer: 'allow',
    librarian: 'allow',
  });
  assert.deepEqual(opencode.agent.plan.permission.edit, {
    '.env.example': 'deny',
    '**/.env.example': 'deny',
  });
  for (const toolName of ['write', 'ast_grep_replace']) {
    assert.equal(
      opencode.agent.plan.permission[toolName],
      'deny',
      `plan must deny ${toolName}`,
    );
  }
  for (const toolName of taskControls.slice(1)) {
    assert.equal(
      opencode.agent.plan.permission[toolName],
      'deny',
      `plan must deny ${toolName}`,
    );
  }

  assert.equal(
    slim.$schema,
    'https://unpkg.com/oh-my-opencode-slim@2.2.17/oh-my-opencode-slim.schema.json',
  );
  assert.equal(slim.preset, 'generic-openai');
  assert.deepEqual(slim.disabled_agents, []);
  assert.equal(slim.image_routing, 'auto');
  assert.deepEqual(slim.fallback, { enabled: false });
  assert.equal(slim.backgroundJobs.orchestratorWake.enabled, false);
  assert.equal('timeout' in slim.council, false);
  assert.equal('councillor_retries' in slim.council, false);
  assert.deepEqual(preset.librarian.mcps, ['context7', 'gh_grep']);
  assert.deepEqual(
    {
      orchestrator: [preset.orchestrator.model, preset.orchestrator.variant],
      oracle: [preset.oracle.model, preset.oracle.variant],
      council: [preset.council.model, preset.council.variant],
      explorer: [preset.explorer.model, preset.explorer.variant],
      librarian: [preset.librarian.model, preset.librarian.variant],
      fixer: [preset.fixer.model, preset.fixer.variant],
      designer: [preset.designer.model, preset.designer.variant],
      observer: [preset.observer.model, preset.observer.variant],
    },
    {
      orchestrator: [models.balanced, 'high'],
      oracle: [models.primary, 'max'],
      council: [models.primary, 'high'],
      explorer: [models.utility, 'low'],
      librarian: [models.utility, 'low'],
      fixer: [models.utility, 'high'],
      designer: [models.balanced, 'medium'],
      observer: [models.utility, 'medium'],
    },
  );
  for (const [name, model, variant] of [
    ['code-reviewer', models.balanced, 'high'],
    ['repo-architect', models.primary, 'high'],
    ['test-writer', models.balanced, 'medium'],
    ['security-reviewer', models.primary, 'high'],
  ]) {
    assert.equal(slim.agents[name].model, model, `${name} model`);
    assert.equal(slim.agents[name].variant, variant, `${name} effort`);
  }
  for (const [name, model, variant] of [
    ['deep-review', models.deep, 'max'],
    ['fast-sanity', models.utility, 'low'],
    ['security-sanity', models.balanced, 'high'],
  ]) {
    assert.equal(council[name].model, model, `${name} model`);
    assert.equal(council[name].variant, variant, `${name} effort`);
  }

  const promptDir = join(configDir, 'oh-my-opencode-slim');
  const orchestratorAppend = readFileSync(join(promptDir, 'orchestrator_append.md'), 'utf8');
  const projectInstructions = readFileSync(join(promptDir, 'project-instructions.md'), 'utf8');
  assert.equal(existsSync(join(promptDir, 'orchestrator.md')), false);
  assert.equal(orchestratorAppend.includes('remain the coordinator'), true);
  assert.equal(orchestratorAppend.includes("OpenCode's native Plan agent"), true);
  assert.equal(orchestratorAppend.includes('Stop once the requested outcome is complete'), true);
  assert.equal(projectInstructions.includes('Do not replace it with broader engineering goals'), true);
  assert.equal(projectInstructions.includes('Build, Fixer, and Designer execute their assigned bounded work directly'), true);
  assert.equal(projectInstructions.includes('independent deep slot'), true);
  assert.equal(orchestratorAppend.includes('independent deep slot'), true);
  const workflow = readFileSync(join(configDir, 'skills', 'project-workflow', 'SKILL.md'), 'utf8');
  assert.equal(workflow.includes('Orchestrator only:'), true);
  assert.equal(workflow.includes('Build, Fixer, and Designer execute their assigned bounded work directly'), true);
}

function runInstaller(target, sourceFixture, options = {}) {
  const customInput = options.input ?? (options.custom
    ? [
        'y',
        options.custom.primary,
        options.custom.balanced,
        options.custom.utility,
        options.custom.deep,
        '',
      ].join('\n')
    : undefined);
  const forceArgs = options.force ? ['--force'] : [];

  let command;
  let args;
  const env = {
    ...process.env,
    OPENCODE_BIN: options.opencodeBin ?? '__opencode_test_missing__',
    OPENCODE_TEMPLATE_SOURCE: useBash ? sourceFixture.replaceAll('\\', '/') : sourceFixture,
    MODEL_QUERY_MARKER: options.queryMarker,
  };
  if (!useBash) {
    command = 'powershell.exe';
    args = [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      join(repoRoot, 'scripts', 'install.ps1'),
      '-ProjectPath',
      target,
      ...(options.force ? ['-Force'] : []),
      ...(customInput === undefined ? ['-NonInteractive'] : []),
    ];
  } else {
    command = process.env.BASH_BIN ?? 'bash';
    args = [
      join(repoRoot, 'scripts', 'install.sh').replaceAll('\\', '/'),
      target.replaceAll('\\', '/'),
      ...forceArgs,
      ...(customInput === undefined ? ['--non-interactive'] : []),
    ];
  }

  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    env,
    input: customInput,
    timeout: 30000,
  });
  assert.ifError(result.error);
  if (options.error) {
    assert.notEqual(result.status, 0, 'Invalid installation must fail');
    assert.equal(`${result.stdout}\n${result.stderr}`.includes(options.error), true);
    return;
  }
  assert.equal(
    result.status,
    0,
    `Installer failed.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
  );
}

function assertNoRuntimeArtifacts(configDir) {
  for (const name of ['.gitignore', 'node_modules', 'package.json', 'package-lock.json', 'bun.lock']) {
    assert.equal(existsSync(join(configDir, name)), false, `${name} must not be installed`);
  }
}

const defaultModels = {
  primary: 'openai/gpt-5.6-sol',
  balanced: 'openai/gpt-5.6-terra',
  utility: 'openai/gpt-5.6-luna',
  deep: 'openai/gpt-5.6-sol',
};
const customModels = {
  primary: 'openai/test-primary',
  balanced: 'openai/test-balanced',
  utility: 'openai/test-utility',
  deep: 'openai/test-deep',
};

assertTemplate(templateDir, defaultModels);

const envLines = new Set(
  readFileSync(join(templateDir, 'opencode.env'), 'utf8')
    .split(/\r?\n/)
    .filter(Boolean),
);
assert.equal(envLines.has('OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true'), true);
assert.equal(envLines.has('OPENCODE_ENABLE_EXA=1'), true);
assert.equal(envLines.has('OH_MY_OPENCODE_SLIM_PRESET=generic-openai'), true);

const readme = readFileSync(join(repoRoot, 'README.md'), 'utf8');
assert.equal(readme.includes('OpenCode 1.18.29'), true);
assert.equal(readme.includes('OMOS 2.2.17'), true);
assert.equal(readme.includes('gpt-5.6-sol-pro'), false);
assert.equal(readme.includes('2.0.5'), false);
assert.equal(readme.includes('1.17.12'), false);

const tempRoot = mkdtempSync(join(tmpdir(), 'opencode-config-test-'));
try {
  const sourceFixture = join(tempRoot, 'contaminated template');
  mkdirSync(sourceFixture);
  for (const entry of templateEntries) {
    cpSync(join(templateDir, entry), join(sourceFixture, entry), { recursive: true });
  }
  mkdirSync(join(sourceFixture, 'node_modules'));
  writeFileSync(join(sourceFixture, 'node_modules', 'runtime-cache.txt'), 'exclude me\n');
  for (const name of ['.gitignore', 'package.json', 'package-lock.json', 'bun.lock']) {
    writeFileSync(join(sourceFixture, name), 'exclude me\n');
  }

  const target = join(tempRoot, 'project with spaces');
  mkdirSync(target);
  runInstaller(target, sourceFixture, { custom: customModels });
  assertTemplate(join(target, '.opencode'), customModels);
  assertNoRuntimeArtifacts(join(target, '.opencode'));

  for (const relative of ['orchestrator.md', 'generic-openai/orchestrator.md']) {
    const overrideTarget = join(tempRoot, relative.replaceAll('/', '-'));
    cpSync(target, overrideTarget, { recursive: true });
    const overridePath = join(overrideTarget, '.opencode', 'oh-my-opencode-slim', relative);
    mkdirSync(dirname(overridePath), { recursive: true });
    for (const text of ['# Goal-Focused Orchestrator\nDo not delegate by default.\n', '# My customized full prompt\n']) {
      writeFileSync(overridePath, text);
      const before = readFileSync(join(overrideTarget, '.opencode', 'opencode.jsonc'), 'utf8');
      runInstaller(overrideTarget, sourceFixture, {
        force: true,
        error: 'Full orchestrator prompt override',
      });
      assert.equal(readFileSync(overridePath, 'utf8'), text);
      assert.equal(readFileSync(join(overrideTarget, '.opencode', 'opencode.jsonc'), 'utf8'), before);
    }
  }

  const queryMarker = join(tempRoot, 'catalog-query.log').replaceAll('\\', '/');
  const opencodeBin = join(tempRoot, useBash ? 'mock-opencode.sh' : 'mock-opencode.cmd').replaceAll('\\', '/');
  writeFileSync(opencodeBin, useBash
    ? '#!/usr/bin/env bash\nprintf "queried\\n" >> "$MODEL_QUERY_MARKER"\nprintf "openai/gpt-6-astra\\n"\n'
    : '@echo off\necho queried>>"%MODEL_QUERY_MARKER%"\necho openai/gpt-6-astra\n', { mode: 0o755 });
  const quietTarget = join(tempRoot, 'no catalog needed');
  mkdirSync(quietTarget);
  runInstaller(quietTarget, sourceFixture, { opencodeBin, queryMarker });
  assert.equal(existsSync(queryMarker), false, 'Noninteractive install must not query models');
  runInstaller(quietTarget, sourceFixture, { opencodeBin, queryMarker, force: true, input: 'n\n' });
  assert.equal(existsSync(queryMarker), false, 'Declining customization must not query models');
  runInstaller(quietTarget, sourceFixture, {
    opencodeBin, queryMarker, force: true,
    input: 'y\n1\n\n\n1\n',
  });
  assert.equal(existsSync(queryMarker), true, 'Custom install must query models');
  assertTemplate(join(quietTarget, '.opencode'), {
    ...defaultModels, primary: 'openai/gpt-6-astra', deep: 'openai/gpt-6-astra',
  });

  for (const utility of ['openai/gpt-6-astra', 'openai/gpt-6-astra-fast']) {
    const invalidTarget = join(tempRoot, utility.split('/')[1]);
    mkdirSync(invalidTarget);
    const invalidOptions = {
      custom: { ...defaultModels, utility },
      error: 'Astra cannot fill the utility slot',
    };
    runInstaller(invalidTarget, sourceFixture, invalidOptions);
    assert.equal(existsSync(join(invalidTarget, '.opencode')), false);
    runInstaller(target, sourceFixture, { ...invalidOptions, force: true });
    assertTemplate(join(target, '.opencode'), customModels);
  }

  const astraTarget = join(tempRoot, 'astra project');
  const astraModels = {
    ...defaultModels,
    primary: 'openai/gpt-6-astra',
    deep: 'openai/gpt-6-astra',
  };
  mkdirSync(astraTarget);
  runInstaller(astraTarget, sourceFixture, { custom: astraModels });
  assertTemplate(join(astraTarget, '.opencode'), astraModels);

  const preservedFile = join(target, '.opencode', 'preserved-by-force.txt');
  writeFileSync(preservedFile, 'preserve me\n');
  runInstaller(target, sourceFixture, { force: true });
  assert.equal(existsSync(preservedFile), true);
  assertTemplate(join(target, '.opencode'), defaultModels);
  assertNoRuntimeArtifacts(join(target, '.opencode'));
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}

console.log(`Config and ${useBash ? 'Bash' : 'PowerShell'} installer checks: OK`);

if (process.argv.includes('--opencode')) {
  const output = {};
  for (const [name, args] of [
    ['config', ['debug', 'config']],
    ['models', ['models', 'openai', '--verbose']],
  ]) {
    const result = spawnSync(
      process.platform === 'win32' ? process.env.ComSpec : 'opencode',
      process.platform === 'win32' ? ['/d', '/c', `opencode.cmd ${args.join(' ')}`] : args,
      {
        cwd: join(repoRoot, 'template'), encoding: 'utf8', timeout: 120000, maxBuffer: 8e6,
        env: {
          ...process.env,
          OH_MY_OPENCODE_SLIM_PRESET: 'generic-openai',
          OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS: 'true',
          OPENCODE_ENABLE_EXA: '1',
        },
      },
    );
    assert.ifError(result.error);
    assert.equal(result.status, 0, `OpenCode ${name} check failed: ${result.stderr}`);
    output[name] = result.stdout;
  }
  const resolved = JSON.parse(output.config);
  const catalog = Object.fromEntries(output.models.trim()
    .split(/(?=^openai\/[^\r\n]+\r?$)/m).filter(Boolean).map(block => {
      const newline = block.indexOf('\n');
      return [block.slice(0, newline).trim(), JSON.parse(block.slice(newline + 1))];
    }));
  const core = readJson(opencodePath);
  const slim = readJson(slimPath);
  const expected = {
    ...core.agent,
    ...slim.presets['generic-openai'],
    ...slim.agents,
    ...Object.fromEntries(Object.entries(slim.council.presets['generic-review-board'])
      .map(([name, agent]) => [`councillor-${name}`, agent])),
  };
  assert.equal(resolved.model, core.model, 'Effective default model');
  assert.equal(resolved.small_model, core.small_model, 'Effective small model');
  for (const [name, agent] of Object.entries(expected)) {
    if (!agent.model) continue;
    const hint = `${name}: check inherited OMOS agents and core agent overrides`;
    assert.equal(resolved.agent?.[name]?.model, agent.model, `${hint} (model)`);
    assert.equal(resolved.agent?.[name]?.variant, agent.variant, `${hint} (effort)`);
    assert.ok(catalog[agent.model], `${name}: ${agent.model} is missing from the host catalog`);
    assert.ok(catalog[agent.model].variants?.[agent.variant], `${name}: unsupported effort ${agent.variant}`);
  }
  console.log('OpenCode effective routing and model catalog checks: OK (no inference requests)');
}
