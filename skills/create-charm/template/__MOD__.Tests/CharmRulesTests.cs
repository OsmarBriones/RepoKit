using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace __MOD__.Tests;

/// <summary>
/// The workspace rules every Charm mod must follow (see RepoKit/skills/create-charm/SKILL.md), checked on the source
/// files so a charm that breaks them fails <c>dotnet test</c> instead of reaching players. Do not delete or weaken
/// these tests; fix the charm instead.
/// </summary>
[TestClass]
public class CharmRulesTests
{
	private static readonly string Root = FindModRoot();

	[TestMethod]
	public void Charm_DerivesFromCharmAndIsRegistered()
	{
		string all = string.Join("\n", ModSources().Select(File.ReadAllText));
		Assert.IsTrue(all.Contains(": Charm"), "No class derives from CharmCore's Charm.");
		Assert.IsTrue(all.Contains("CharmsApi.Register("), "The charm is never registered with CharmsApi.Register.");
	}

	[TestMethod]
	public void DebugDetail_GoesThroughLogDebug()
	{
		// Startup lines belong to the plugin class; everything else must use Charm.LogDebug, which respects DebugMode.
		List<string> offenders = new List<string>();
		foreach (string file in ModSources().Where(path => !path.EndsWith("Plugin.cs", StringComparison.Ordinal)))
		{
			foreach (string line in File.ReadAllLines(file))
			{
				if (line.Contains("Logger.LogInfo(") || line.Contains("Logger.LogMessage(") || line.Contains("Logger.LogDebug("))
				{
					offenders.Add(Path.GetFileName(file) + ": " + line.Trim());
				}
			}
		}

		Assert.AreEqual(0, offenders.Count, "Use Charm.LogDebug for debug detail instead of the logger:\n" + string.Join("\n", offenders));
	}

	[TestMethod]
	public void Manifest_DependsOnPocketsAndCharmCore()
	{
		string manifest = File.ReadAllText(Path.Combine(Root, "manifest.json"));
		Assert.IsTrue(manifest.Contains("OsmarBriones-Pockets-"), "manifest.json must depend on OsmarBriones-Pockets.");
		Assert.IsTrue(manifest.Contains("OsmarBriones-CharmCore-"), "manifest.json must depend on OsmarBriones-CharmCore.");
	}

	[TestMethod]
	public void Readme_DocumentsDebugMode()
	{
		string readme = File.ReadAllText(Path.Combine(Root, "README.md"));
		Assert.IsTrue(readme.Contains("DebugMode"), "README.md must document the Debug section and DebugMode.");
	}

	[TestMethod]
	public void QaBattery_StartsWithDebugMode()
	{
		string[] batteries = Directory.GetFiles(Path.Combine(Root, "specs"), "qa-battery.md", SearchOption.AllDirectories);
		Assert.IsTrue(batteries.Length > 0, "specs/<feature>/qa-battery.md is missing.");
		Assert.IsTrue(batteries.Any(path => File.ReadAllText(path).Contains("DebugMode")), "The QA battery must explain how to test with DebugMode.");
	}

	private static IEnumerable<string> ModSources()
	{
		string[] skipped = { "obj", "bin", "external", ".git" };
		return Directory.GetFiles(Root, "*.cs", SearchOption.AllDirectories).Where(path =>
		{
			string relative = path.Substring(Root.Length).TrimStart(Path.DirectorySeparatorChar);
			string first = relative.Split(Path.DirectorySeparatorChar)[0];
			return !skipped.Contains(first) && !first.EndsWith(".Tests", StringComparison.Ordinal);
		});
	}

	private static string FindModRoot()
	{
		DirectoryInfo? directory = new DirectoryInfo(AppContext.BaseDirectory);
		while (directory != null && !File.Exists(Path.Combine(directory.FullName, "manifest.json")))
		{
			directory = directory.Parent;
		}

		return directory?.FullName ?? throw new InvalidOperationException("manifest.json was not found above the test assembly.");
	}
}
