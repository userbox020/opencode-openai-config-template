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
  assert.equal(opencode.agent.build.model, models.primary);
  assert.equal(opencode.agent.general.model, models.balanced);
  assert.equal(opencode.agent.explore.model, models.utility);
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
  assert.equal(slim.agents['code-reviewer'].model, models.balanced);
  assert.equal(slim.agents['repo-architect'].model, models.primary);
  assert.equal(council['deep-review'].model, models.deep);
  assert.equal(council['deep-review'].variant, 'max');
  assert.equal(council['fast-sanity'].model, models.utility);
  assert.equal(council['security-sanity'].model, models.balanced);

  const promptDir = join(configDir, 'oh-my-opencode-slim');
  const orchestratorAppend = readFileSync(join(promptDir, 'orchestrator_append.md'), 'utf8');
  const projectInstructions = readFileSync(join(promptDir, 'project-instructions.md'), 'utf8');
  assert.equal(existsSync(join(promptDir, 'orchestrator.md')), false);
  assert.equal(orchestratorAppend.includes('remain the coordinator'), true);
  assert.equal(orchestratorAppend.includes("OpenCode's native Plan agent"), true);
  assert.equal(orchestratorAppend.includes('Stop once the requested outcome is complete'), true);
  assert.equal(projectInstructions.includes('Do not replace it with broader engineering goals'), true);
}

function runInstaller(target, sourceFixture, options = {}) {
  const customInput = options.custom
    ? [
        'y',
        options.custom.primary,
        options.custom.balanced,
        options.custom.utility,
        options.custom.deep,
        '',
      ].join('\n')
    : undefined;
  const forceArgs = options.force ? ['--force'] : [];

  let command;
  let args;
  const env = {
    ...process.env,
    OPENCODE_BIN: '__opencode_test_missing__',
    OPENCODE_TEMPLATE_SOURCE: sourceFixture,
  };
  if (process.platform === 'win32') {
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
      ...(options.custom ? [] : ['-NonInteractive']),
    ];
  } else {
    command = 'bash';
    args = [
      join(repoRoot, 'scripts', 'install.sh'),
      target,
      ...forceArgs,
      ...(options.custom ? [] : ['--non-interactive']),
    ];
  }

  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    env,
    input: customInput,
  });
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
assert.equal(readme.includes('OpenCode 1.18.26'), true);
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

  const preservedFile = join(target, '.opencode', 'preserved-by-force.txt');
  writeFileSync(preservedFile, 'preserve me\n');
  runInstaller(target, sourceFixture, { force: true });
  assert.equal(existsSync(preservedFile), true);
  assertTemplate(join(target, '.opencode'), defaultModels);
  assertNoRuntimeArtifacts(join(target, '.opencode'));
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}

console.log(`Config and ${process.platform === 'win32' ? 'PowerShell' : 'Bash'} installer checks: OK`);
