const assert = require("assert")
const fs = require("fs")
const path = require("path")

const root = path.resolve(__dirname, "..")
const configDir = path.join(root, "template", ".opencode")

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.join(configDir, name), "utf8"))
}

async function resolveCoreProfile(name) {
  const pluginPath = path.join(configDir, "routing-profile.js")
  const source = fs
    .readFileSync(pluginPath, "utf8")
    .replace("export default async () =>", "return async () =>")
  const loadPlugin = new Function(source)()
  const previousPublic = process.env.OPENCODE_ROUTING_PROFILE
  const previousSlim = process.env.OH_MY_OPENCODE_SLIM_PRESET

  try {
    process.env.OPENCODE_ROUTING_PROFILE = name
    delete process.env.OH_MY_OPENCODE_SLIM_PRESET
    const plugin = await loadPlugin()
    const config = { agent: {} }
    await plugin.config(config)
    return { config, slimProfile: process.env.OH_MY_OPENCODE_SLIM_PRESET }
  } finally {
    if (previousPublic === undefined) delete process.env.OPENCODE_ROUTING_PROFILE
    else process.env.OPENCODE_ROUTING_PROFILE = previousPublic
    if (previousSlim === undefined) delete process.env.OH_MY_OPENCODE_SLIM_PRESET
    else process.env.OH_MY_OPENCODE_SLIM_PRESET = previousSlim
  }
}

function route(model, variant) {
  return { model, variant }
}

function assertRoute(actual, expected) {
  assert.deepStrictEqual(
    { model: actual.model, variant: actual.variant },
    expected,
  )
}

async function main() {
  const primary = "openai/gpt-5.6-sol"
  const balanced = "openai/gpt-5.6-terra"
  const utility = "openai/gpt-5.6-luna"
  const opencode = readJson("opencode.jsonc")
  const slim = readJson("oh-my-opencode-slim.jsonc")

  assert.deepStrictEqual(opencode.plugin.slice(0, 2), [
    "./routing-profile.js",
    "oh-my-opencode-slim@2.0.5",
  ])

  const balancedCore = await resolveCoreProfile("balanced")
  assert.strictEqual(balancedCore.slimProfile, "balanced")
  assert.strictEqual(balancedCore.config.model, balanced)
  assert.strictEqual(balancedCore.config.small_model, utility)
  assertRoute(balancedCore.config.agent.build, route(balanced, "medium"))
  assertRoute(balancedCore.config.agent.plan, route(primary, "high"))
  assertRoute(balancedCore.config.agent.summary, route(utility, "low"))

  const qualityCore = await resolveCoreProfile("quality")
  assert.strictEqual(qualityCore.slimProfile, "quality")
  assert.strictEqual(qualityCore.config.model, primary)
  assert.strictEqual(qualityCore.config.small_model, balanced)
  assertRoute(qualityCore.config.agent.build, route(primary, "medium"))
  assertRoute(qualityCore.config.agent.plan, route(primary, "xhigh"))
  assertRoute(qualityCore.config.agent.compaction, route(primary, "medium"))

  const invalidCore = await resolveCoreProfile("constructor")
  assert.strictEqual(invalidCore.slimProfile, "balanced")
  assert.strictEqual(invalidCore.config.model, balanced)

  assertRoute(slim.presets.balanced.oracle, route(primary, "xhigh"))
  assertRoute(slim.presets.balanced.explorer, route(utility, "low"))
  assertRoute(
    slim.presets.balanced["code-reviewer"],
    route(balanced, "high"),
  )
  assertRoute(slim.presets.quality.oracle, route(primary, "max"))
  assertRoute(slim.presets.quality.explorer, route(balanced, "low"))
  assertRoute(
    slim.presets.quality["code-reviewer"],
    route(primary, "xhigh"),
  )

  for (const [profileName, profile] of Object.entries(slim.presets)) {
    const arrayRoutes = Object.entries(profile).filter(([, value]) =>
      Array.isArray(value.model),
    )
    assert.deepStrictEqual(
      arrayRoutes.map(([name]) => name).sort(),
      ["designer", "orchestrator"],
      `${profileName} has an unexpected fallback route`,
    )
    for (const [, value] of arrayRoutes) {
      assert(value.model.every((entry) => entry.variant === "medium"))
    }
  }

  assert.strictEqual(
    slim.council.default_preset,
    "{env:OH_MY_OPENCODE_SLIM_PRESET}",
  )
  assertRoute(
    slim.council.presets.balanced["deep-review"],
    route(primary, "xhigh"),
  )
  assertRoute(
    slim.council.presets.quality["deep-review"],
    route(primary, "max"),
  )

  assert(!/openai\/[^\"]*-pro\"/.test(JSON.stringify(opencode)))
  assert(!/openai\/[^\"]*-pro\"/.test(JSON.stringify(slim)))
  console.log("ROUTING_TESTS_OK")
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
