const models = {
  primary: "openai/gpt-5.6-sol",
  balanced: "openai/gpt-5.6-terra",
  utility: "openai/gpt-5.6-luna",
}

const profiles = {
  balanced: {
    model: models.balanced,
    smallModel: models.utility,
    agents: {
      build: [models.balanced, "medium"],
      plan: [models.primary, "high"],
      general: [models.balanced, "medium"],
      explore: [models.utility, "low"],
      title: [models.utility, "none"],
      summary: [models.utility, "low"],
      compaction: [models.balanced, "medium"],
    },
  },
  quality: {
    model: models.primary,
    smallModel: models.balanced,
    agents: {
      build: [models.primary, "medium"],
      plan: [models.primary, "xhigh"],
      general: [models.primary, "medium"],
      explore: [models.balanced, "low"],
      title: [models.utility, "none"],
      summary: [models.balanced, "medium"],
      compaction: [models.primary, "medium"],
    },
  },
}

export default async () => {
  const requested = (
    process.env.OPENCODE_ROUTING_PROFILE ??
    process.env.OH_MY_OPENCODE_SLIM_PRESET ??
    "balanced"
  ).toLowerCase()
  const profileName = Object.prototype.hasOwnProperty.call(profiles, requested)
    ? requested
    : "balanced"

  if (requested !== profileName) {
    console.warn(
      `[routing-profile] Unknown profile "${requested}"; using "balanced".`,
    )
  }

  process.env.OPENCODE_ROUTING_PROFILE = profileName
  process.env.OH_MY_OPENCODE_SLIM_PRESET = profileName

  return {
    config(config) {
      const profile = profiles[profileName]
      config.model = profile.model
      config.small_model = profile.smallModel
      config.agent ??= {}

      for (const [name, [model, variant]] of Object.entries(profile.agents)) {
        config.agent[name] = {
          ...(config.agent[name] ?? {}),
          model,
          variant,
        }
      }
    },
  }
}
