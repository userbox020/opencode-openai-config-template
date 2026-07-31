const assert = require("assert")
const childProcess = require("child_process")
const fs = require("fs")
const os = require("os")
const path = require("path")

const root = path.resolve(__dirname, "..")

function runInstaller(target, input, jsonRuntime) {
  const isWindows = process.platform === "win32"
  const command = isWindows ? "powershell" : "bash"
  const args = isWindows
    ? [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        path.join(root, "scripts", "install.ps1"),
        "-ProjectPath",
        target,
        ...(input ? [] : ["-NonInteractive"]),
      ]
    : [
        path.join(root, "scripts", "install.sh"),
        target,
        ...(input ? [] : ["--non-interactive"]),
      ]
  const env = {
    ...process.env,
    OPENCODE_BIN: "opencode-test-missing",
    NON_INTERACTIVE: input ? "0" : "1",
    FORCE: "0",
    ...(jsonRuntime ? { OPENCODE_INSTALL_JSON_RUNTIME: jsonRuntime } : {}),
  }
  const result = childProcess.spawnSync(command, args, {
    cwd: root,
    env,
    input,
    encoding: "utf8",
    timeout: 120000,
  })

  if (result.status !== 0) {
    throw new Error(
      `Installer failed (${result.status})\n${result.stdout}\n${result.stderr}`,
    )
  }
  return `${result.stdout}\n${result.stderr}`
}

function readJson(configDir, name) {
  return JSON.parse(fs.readFileSync(path.join(configDir, name), "utf8"))
}

function assertInstalled(target, models) {
  const configDir = path.join(target, ".opencode")
  const opencode = readJson(configDir, "opencode.jsonc")
  const slim = readJson(configDir, "oh-my-opencode-slim.jsonc")
  const routing = fs.readFileSync(
    path.join(configDir, "routing-profile.js"),
    "utf8",
  )

  assert.strictEqual(opencode.model, models.balanced)
  assert.strictEqual(opencode.small_model, models.utility)
  assert.strictEqual(opencode.agent.build.model, models.balanced)
  assert.strictEqual(opencode.agent.plan.model, models.primary)
  assert.strictEqual(opencode.agent.general.model, models.balanced)
  assert.strictEqual(opencode.agent.explore.model, models.utility)
  assert.strictEqual(opencode.agent.title.model, models.utility)
  assert.strictEqual(opencode.agent.summary.model, models.utility)
  assert.strictEqual(opencode.agent.compaction.model, models.balanced)
  assert.deepStrictEqual(
    Object.fromEntries(
      Object.entries(opencode.agent).map(([name, value]) => [
        name,
        value.variant,
      ]),
    ),
    {
      build: "medium",
      plan: "high",
      general: "medium",
      explore: "low",
      title: "none",
      summary: "low",
      compaction: "medium",
    },
  )
  assert(routing.includes(`primary: ${JSON.stringify(models.primary)}`))
  assert(routing.includes(`balanced: ${JSON.stringify(models.balanced)}`))
  assert(routing.includes(`utility: ${JSON.stringify(models.utility)}`))

  assert.strictEqual(
    slim.presets.balanced.orchestrator.model[0].id,
    models.balanced,
  )
  assert.strictEqual(
    slim.presets.balanced.orchestrator.model[1].id,
    models.primary,
  )
  assert.strictEqual(slim.presets.balanced.oracle.model, models.primary)
  assert.strictEqual(slim.presets.balanced.council.model, models.primary)
  assert.strictEqual(slim.presets.balanced.explorer.model, models.utility)
  assert.strictEqual(slim.presets.balanced.librarian.model, models.balanced)
  assert.strictEqual(slim.presets.balanced.fixer.model, models.primary)
  assert.strictEqual(
    slim.presets.balanced.designer.model[0].id,
    models.balanced,
  )
  assert.strictEqual(
    slim.presets.balanced.designer.model[1].id,
    models.primary,
  )
  assert.strictEqual(
    slim.presets.balanced["code-reviewer"].model,
    models.balanced,
  )
  assert.strictEqual(
    slim.presets.balanced["repo-architect"].model,
    models.primary,
  )
  assert.strictEqual(
    slim.presets.balanced["test-writer"].model,
    models.balanced,
  )
  assert.strictEqual(
    slim.presets.balanced["security-reviewer"].model,
    models.primary,
  )
  assert.strictEqual(
    slim.presets.quality.orchestrator.model[0].id,
    models.primary,
  )
  assert.strictEqual(
    slim.presets.quality.orchestrator.model[1].id,
    models.balanced,
  )
  assert.strictEqual(slim.presets.quality.oracle.model, models.primary)
  assert.strictEqual(slim.presets.quality.council.model, models.primary)
  assert.strictEqual(slim.presets.quality.explorer.model, models.balanced)
  assert.strictEqual(slim.presets.quality.librarian.model, models.primary)
  assert.strictEqual(slim.presets.quality.fixer.model, models.primary)
  assert.strictEqual(
    slim.presets.quality.designer.model[0].id,
    models.primary,
  )
  assert.strictEqual(
    slim.presets.quality.designer.model[1].id,
    models.balanced,
  )
  for (const name of [
    "code-reviewer",
    "repo-architect",
    "test-writer",
    "security-reviewer",
  ]) {
    assert.strictEqual(slim.presets.quality[name].model, models.primary)
  }
  assert.strictEqual(
    slim.council.presets.balanced["fast-sanity"].model,
    models.utility,
  )
  assert.strictEqual(
    slim.council.presets.quality["deep-review"].model,
    models.primary,
  )
  assert.strictEqual(
    slim.council.presets.balanced["deep-review"].model,
    models.primary,
  )
  assert.strictEqual(
    slim.council.presets.balanced["security-sanity"].model,
    models.balanced,
  )
  assert.strictEqual(
    slim.council.presets.quality["fast-sanity"].model,
    models.balanced,
  )
  assert.strictEqual(
    slim.council.presets.quality["security-sanity"].model,
    models.primary,
  )
  const profileVariants = {
    balanced: {
      orchestrator: "medium",
      oracle: "xhigh",
      council: "high",
      explorer: "low",
      librarian: "low",
      fixer: "high",
      designer: "medium",
      "code-reviewer": "high",
      "repo-architect": "high",
      "test-writer": "medium",
      "security-reviewer": "high",
    },
    quality: {
      orchestrator: "medium",
      oracle: "max",
      council: "xhigh",
      explorer: "low",
      librarian: "medium",
      fixer: "xhigh",
      designer: "medium",
      "code-reviewer": "xhigh",
      "repo-architect": "xhigh",
      "test-writer": "high",
      "security-reviewer": "xhigh",
    },
  }
  for (const [profileName, variants] of Object.entries(profileVariants)) {
    for (const [agentName, variant] of Object.entries(variants)) {
      const configured = slim.presets[profileName][agentName]
      if (Array.isArray(configured.model)) {
        assert(configured.model.every((entry) => entry.variant === variant))
      } else {
        assert.strictEqual(configured.variant, variant)
      }
    }
  }
  for (const [profileName, variants] of Object.entries({
    balanced: {
      "deep-review": "xhigh",
      "fast-sanity": "low",
      "security-sanity": "high",
    },
    quality: {
      "deep-review": "max",
      "fast-sanity": "low",
      "security-sanity": "high",
    },
  })) {
    for (const [name, variant] of Object.entries(variants)) {
      assert.strictEqual(
        slim.council.presets[profileName][name].variant,
        variant,
      )
    }
  }
  assert(!/openai\/[^\"]*-pro\"/.test(JSON.stringify(opencode)))
  assert(!/openai\/[^\"]*-pro\"/.test(JSON.stringify(slim)))
}

function main() {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "opencode-routing-test-"))
  const defaultTarget = path.join(tempRoot, "default")
  const customTarget = path.join(tempRoot, "custom")
  const pythonTarget = path.join(tempRoot, "python")
  fs.mkdirSync(defaultTarget)
  fs.mkdirSync(customTarget)

  try {
    runInstaller(defaultTarget)
    assertInstalled(defaultTarget, {
      primary: "openai/gpt-5.6-sol",
      balanced: "openai/gpt-5.6-terra",
      utility: "openai/gpt-5.6-luna",
    })

    const customInput = [
      "y",
      "openai/gpt-5.6-sol-pro",
      "openai/gpt-5.6-terra",
      "openai/gpt-5.6-sol",
      "openai/gpt-5.4-mini",
      "",
    ].join(os.EOL)
    const output = runInstaller(customTarget, customInput)
    assert(output.includes("Pro-mode IDs"))
    assertInstalled(customTarget, {
      primary: "openai/gpt-5.6-terra",
      balanced: "openai/gpt-5.6-sol",
      utility: "openai/gpt-5.4-mini",
    })

    if (process.platform !== "win32") {
      const python = childProcess.spawnSync("python3", ["--version"], {
        encoding: "utf8",
      })
      if (python.status === 0) {
        fs.mkdirSync(pythonTarget)
        const pythonOutput = runInstaller(pythonTarget, customInput, "python3")
        assert(pythonOutput.includes("Pro-mode IDs"))
        assertInstalled(pythonTarget, {
          primary: "openai/gpt-5.6-terra",
          balanced: "openai/gpt-5.6-sol",
          utility: "openai/gpt-5.4-mini",
        })
      }
    }
    console.log("INSTALLER_TESTS_OK")
  } finally {
    fs.rmSync(tempRoot, { recursive: true, force: true })
  }
}

main()
