using CharmCore.Api;

namespace __MOD__
{
	/// <summary>__EFFECT__: __SUMMARY__</summary>
	internal sealed class __NAME__Charm : Charm
	{
		internal const string PrefabName = "__PREFAB__";

		internal __NAME__Charm()
			: base("__NAME__", "__DISPLAY__ - __EFFECT__", defaultWearPercent: __WEAR__f, defaultCooldownSeconds: __COOLDOWN__, PrefabName)
		{
			// Extra host-synced numbers for this power go here, for example:
			// Amount = AddSetting("Amount", 30f, 1f, 100f, "Description for the config file.");
		}
	}
}
