---
name: generate-thumbnail
description: Generates or formats a high-quality 256x256 icon.png for a R.E.P.O. mod based on a concept or prompt, adhering to Thunderstore requirements and R.E.P.O. aesthetic.
---

# Generate Thumbnail (Thunderstore Mod Icon)

This skill guides agents in creating or processing a Thunderstore-compliant `icon.png` (256x256 pixels) for any R.E.P.O. mod.

---

## Technical Specifications (Thunderstore)

Parameter | Requirement | Notes
:--- | :--- | :---
**Dimensions** | **Exactly 256x256 pixels** | Thunderstore rejects packages if dimensions differ.
**Aspect Ratio** | 1:1 (Square) | Never use rectangular images.
**Format** | PNG (`.png`) | Transparent or solid background.
**File Name** | `icon.png` | Placed at the root of the mod repository.
**File Size** | < 256 KB | Keep file size small for fast manager loading.

---

## Aesthetic Guidelines for R.E.P.O.

R.E.P.O. has a distinctive comic-horror, grungy retro-industrial aesthetic:
- **Central Subject:** Focus on one clear focal point that represents the mod (e.g. a rubber duck with caution stripes, a glowing weapon, an extraction terminal).
- **High Contrast:** Strong lighting with dark industrial backgrounds (`#101014`, charcoal, rusty metal) and vibrant hazard accents (yellow `#f39c12`, radioactive cyan, warning neon).
- **Legibility at Small Sizes:** Icons appear as small as 64x64 or 32x32 in r2modman / Thunderstore listings. Avoid tiny details or paragraphs of text.

---

## Agent Execution Pathways

### Path A: Agents WITH Image Generation Tool (`generate_image`)
*(E.g. Antigravity, Gemini)*

1. **Formulate a visual prompt:**
   Describe a square, centered, graphic illustration in R.E.P.O.'s dark industrial comic art style:
   ```text
   A vibrant yellow rubber duck sitting on the metal floor of a dark gritty industrial cargo truck, dramatic high-contrast studio lighting, subtle orange neon glow, cel-shaded comic book art style, bold outlines, square composition, video game item icon.
   ```
2. **Call `generate_image`:**
   - `Prompt`: The formulated visual description.
   - `ImageName`: Descriptive identifier (e.g. `ducks_everywhere_icon`).
   - `AspectRatio`: `'1:1'`.
3. **Crop & format to exact 256x256 PNG:**
   Pass the generated image artifact path to the bundled processor script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File external/RepoKit/skills/generate-thumbnail/scripts/process-thumbnail.ps1 `
     -InputImage "<path_to_generated_image>" `
     -OutputPath "./icon.png"
   ```

---

### Path B: Agents WITHOUT Image Generation Tool
*(E.g. Claude, Codex, Terminal LLMs)*

If the agent lacks direct image generation capabilities, choose one of these approaches:

#### 1. Procedural Industrial Badge Generator
Run the bundled PowerShell script to generate a themed 256x256 hazard badge:
```powershell
powershell -ExecutionPolicy Bypass -File external/RepoKit/skills/generate-thumbnail/scripts/generate-procedural-icon.ps1 `
  -Title "Ducks Everywhere" `
  -Subtitle "Truck Rubber Ducks" `
  -OutputPath "./icon.png"
```
This produces a 256x256 PNG with industrial dark gradient, hazard stripes, and clean typography.

#### 2. Process Existing Image
If the user provides an image or artwork:
```powershell
powershell -ExecutionPolicy Bypass -File external/RepoKit/skills/generate-thumbnail/scripts/process-thumbnail.ps1 `
  -InputImage "path/to/source.png" `
  -OutputPath "./icon.png"
```

---

## Verification

After generating or processing the icon, verify its exact dimensions and file size:

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Resolve-Path "./icon.png").Path)
Write-Output "Dimensions: $($img.Width)x$($img.Height), Size: $((Get-Item ./icon.png).Length) bytes"
$img.Dispose()
```

Ensure output is strictly `256x256`.
