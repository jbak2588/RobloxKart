# KDM Place2 Asset Manifest — Track01 (Figure 8) Available Assets

Source: Roblox Official Outdoor/Nature Template (`C:\dev\rbxlx_data\Place2.rbxlx`, 11.16 MB).
Integration Target: `Track01` / `GeometryId=PracticeFigure8V1`, Server Role `RACE`.
Extracted Prefabs:
- `src/assets/KDMHorizonMountainPrefabs.rbxmx` (H1-C1)
- `src/assets/KDMHorizonTreePrefabs.rbxmx` (H1-C3)

---

## 1. Distant Mountain Silhouettes (`Workspace/SkyMountains`)

| Asset Key | Place2 Name | MeshId | TextureID | Size (studs) | Instances | Track01 Utilization Status |
|---|---|---|---|---|---|---|
| **HorizonMountainA** | `MountainMesh` | `rbxassetid://5547037363` | `rbxassetid://16017511205` | `2048×512×2048` (scaled to `512×128×512`) | 14 | **ACTIVE / H1-C1 North Peak** (`pos=(60, 62, 980)`) |
| **HorizonMountainB** | `MountainMesh` | `rbxassetid://5547037419` | `rbxassetid://16017511205` | `2048×512×2048` (scaled to `512×128×512`) | 8 | **ACTIVE / H1-C1 South Range** (`pos=(-60, 62, -820)`) |
| **HorizonMountainC** | `MountainMesh` | `rbxassetid://5547037347` | `rbxassetid://16017511205` | `2048×512×2048` | 1 | **AVAILABLE / Candidate for 360° East/West Ridge** |

- **Draw Call Efficiency:** Single shared texture across all three mountains; ultra-low drawcall / high mobile fidelity.

---

## 2. Foliage & Vegetation (`Workspace/Foliage`)

### A. Mature Deciduous Trees (`Foliage/Trees`)
All models derived from `OB_Tree_a` (2 MeshParts per tree: Trunk + Leaves).

| Model Key | Component | MeshId | SurfaceAppearance | Texture / ColorMap | Dimensions (studs) | Track01 Utilization Status |
|---|---|---|---|---|---|---|
| **NaturalTreeA** (Wide Crown) | Trunk | `rbxassetid://15547670463` | `SA_OB_Bark_a` | Color: `17372965606`<br>Norm: `16101196286`<br>Rough: `17430214798` | `25.4×57.6×23.0` | **ACTIVE / H1-C3 Trees 01 & 02** (Straightaways) |
| | Leaves | `rbxassetid://14824442818` | `SA_OB_TreeLeaves_a` | Color: `16101217575`<br>Pack: `73443296820543`<br>AlphaMode: 1 | `47.8×47.9×52.7` | |
| **NaturalTreeB** (Alternate Crown) | Trunk | `rbxassetid://15547670463` | `SA_OB_Bark_a` | (Same as Trunk above) | `25.4×57.6×23.0` | **ACTIVE / H1-C3 Trees 03 & 04** (Curve Outers) |
| | Leaves | `rbxassetid://89914475582080` | `SA_OB_TreeLeaves_a` | (Same as Leaves above) | `47.4×52.3×53.0` | |

### B. Bushes, Shrubs & Ground Flora
| Model Key | Class | MeshId | SurfaceAppearance | Size (studs) | Place2 Count | Track01 Recommendation |
|---|---|---|---|---|---|---|
| **`OB_Bush_a`** | Model (1 Mesh) | `rbxassetid://14824442818` | `SA_OB_TreeLeaves_a` | `8.1×8.1×8.9` | 12 | Understory under trees, kerb runoff green buffer |
| **`Flowers`** | Clusters | `15922110256`<br>`15922085921`<br>`15921769858` | `SA_Foliage_Atlas_A` | `9.6×3.9×4.9`<br>to `17.4×7.1×8.9` | 104 parts | Infield wildflower accents breaks solid green monotony |
| **`OB_Flowerbox`** | Model (3 Meshes) | `15938318734`<br>`15938318772`<br>`15938519296` | `SA_OB_Trim_A`<br>`SA_Foliage_Atlas_A` | `6.0×2.9×2.4` | 14 | Start/Finish gate & pit lane planter barriers |
| **`OB_Flowers_Hanging`** | Model (3 Meshes) | `15939333760`<br>`15939293893`<br>`15939293906` | `SA_OB_Ivy_a`<br>`SA_OB_Trim_A` | `3.9×7.0×3.1` | 11 | Paddock building wall / lighting post hangings |
| **`Ivy_Grounded_a`** | Model (1 Mesh) | `rbxassetid://15097489086` | `SA_OB_Ivy_a` | `12.4×15.1×6.8` | 20 | Crossover bridge retaining wall base creeper |
| **`Ivy_Hanging_a/b`** | Model (1 Mesh) | `rbxassetid://15091435687`<br>`rbxassetid://15091702891` | `SA_OB_Ivy_a` | `17.5×17.1×6.9`<br>`11.2×14.7×4.1` | 114 | Crossover concrete wall hanging vine foliage |

---

## 3. Circuit Facilities & Wooden Props (`Workspace/Architectural`)

| Model Key | Class | Primary MeshId | SurfaceAppearance | Size (studs) | Place2 Count | Track01 Recommendation |
|---|---|---|---|---|---|---|
| **`OB_Fence_15_a`** | Model (1 Mesh) | `rbxassetid://15922917937` | `SA_OB_Trim_A` | `16.0×7.9×1.6` | 87 | **P1 Recommendation**: Infield boundary & scenic farm fence |
| **`OB_Barrel_a`** | Model (1 Mesh) | `rbxassetid://15929997088` | `SA_OB_Trim_A` | `2.4×3.0×2.4` | 22 | Paddock decor, chicane visual runoff marker |
| **`OB_Crate_a`** | Model (1 Mesh) | `rbxassetid://15929906696` | `SA_OB_Trim_A` | `2.8×2.8×2.8` | 16 | Pit lane tool & supply staging stacks |
| **`OB_Wheelbarrow_a`** | Model (1 Mesh) | `rbxassetid://15929924499` | `SA_OB_Trim_A` | `7.8×2.8×3.1` | 3 | Circuit maintenance corner prop |
| **`OB_MessageBoard_a`** | Model (1 Mesh) | `rbxassetid://15930948852` | `SA_OB_Trim_A` | `6.9×9.9×4.6` | 1 | Wooden leaderboard / driver information board |
| **`OB_Stair_Stone_a`** | Model (1 Mesh) | `rbxassetid://15923461376` | (Stone) | `14.1×12.2×33.0` | 5 | Hillside spectator terraces & crossover access |
| **`OB_Mailbox_a`** | Model (1 Mesh) | `rbxassetid://15931925872` | `SA_OB_Trim_A` | `2.6×4.7×0.6` | 4 | Clubhouse / paddock entry prop |
| **`OB_Well_a`** | Model (3 Meshes) | `16009270856`<br>`15930768031`<br>`16009265058` | `SA_OB_Trim_A` | `9.2×9.7×6.7` | 1 | Infield rural green oasis feature |

---

## 4. Landmark Architecture (`Workspace/Architectural`)

| Model Key | Category | MeshParts | Dimensions (studs) | Primary MeshIds | Track01 Recommendation |
|---|---|---|---|---|---|
| **`OB_Building_A`** | Cottage / Tower | 7 | `16.2×21.9×21.0` | `16007841081`, `16008782022`, `15055578366`, `15055578449` | Race Control / Clubhouse behind Start/Finish line |
| **`OB_Building_B`** | Long Hall | 7 | `16.2×21.9×40.2` | `16008420567`, `15635184365`, `16008420576`, `15635184356` | Pit Garage / Technical inspection garage |
| **`OB_BigTop_a`** | Circus Tent | 1 | `131.4×44.3×109.7` | `rbxassetid://15627291239` | **Grand Horizon Landmark**: 1 single mesh covering 131 studs! |
| **`Ferris Wheel`** | Carnival | 61 | `52.0×60.5×21.3` | `15618395867`, `15612505599` | Carnival amusement horizon backdrop (> 1000 studs away) |
| **`Carousel`** | Carnival | 47 | `25.0×18.0×25.0` | `15579731289`, `15579705434` | Carnival theme companion prop |
| **`OB_Lighthouse_a`** | Tower | 8 | `24.6×42.7×24.6` | `15563675695`, `15563675701`, `15563759865` | Scenic mountain ridge viewing tower |

---

## 5. Lighting & VFX (`Workspace/VFX` & `Lighting_Assets`)

| Asset Key | Class | Details / Content | Track01 Recommendation |
|---|---|---|---|
| **`Lanterns`** | 2 MeshParts | Post: `15931038745`, Glass: `15931038742` | Trackside night lighting posts (28 in Place2) |
| **`Spotlights`** | 2 MeshParts | Base: `15957581356`, Canister: `15957589631` | Stadium floodlight banks for billboard illumination |
| **`Confetti`** | ParticleEmitter (6) | Color confetti textures | **Finish Celebration Gate Trigger** (1st place finish) |
| **`VFX_DustMotes`**| ParticleEmitter | Floating dust/pollen motes | Forest/valley atmospheric volume effect |
| **`vfx_smoke`** | ParticleEmitter | Realistic smoke stream | Chimney / crash / skidmark tire smoke enhancement |

---

## 6. PBR Terrain Material Variants (`MaterialService`)

Ready-to-use Roblox `MaterialVariant`s extracted from Place2:

1. **`Cliff` / `CliffLarge` / `CliffXL`**: Rock face textures for vertical rock walls and midground hills.
2. **`Cobblestone_a`**: Historic circuit cobblestone for paddock and pit lane.
3. **`StoneWall`**: Low rustic stone masonry for safety runoffs.
4. **`Onboarding_WoodPlanks_a`**: Weathered wood planking for footbridges and viewing platforms.
5. **`Moss`**: Soft green moss for shading under trees and creek beds.

---

## 7. Phased Implementation Strategy for Track01

| Phase | Target Scope | Selected Assets | Budget Impact |
|---|---|---|---|
| **H1-C1 (Completed)** | Distant Horizon Mountains | `HorizonMountainA`, `HorizonMountainB` | +2 MeshParts |
| **H1-C2 (Completed)** | Green Valley Ground Continuity | 6 non-colliding tiling BaseParts | +6 BaseParts |
| **H1-C3 (Completed)** | Natural Deciduous Trees (Trial) | 4 models (8 MeshParts) from `Foliage/Trees` | +8 MeshParts |
| **H1-C4 (Completed)** | Full Natural Tree Replacement | 16 total models (32 MeshParts), legacy pines removed | +24 MeshParts (Net server -48 parts) |
| **H1-D1 (Candidate)** | Track Sponsor Arch & Lighting Towers | KDM Sponsor Arch + 2 Spotlights towers | ~10-14 parts |
| **H1-D2 (Candidate)** | Trackside Rural Fencing & Props | `OB_Fence_15_a` (10-16), `OB_Barrel_a` (4) | +14~20 MeshParts |
| **H1-D3 (Candidate)** | Clubhouse & Pit Building | `OB_Building_A`, `OB_Building_B` | +14 MeshParts |
| **H1-D4 (Candidate)** | Finish Gate Celebration VFX | `Confetti` particle system | 0 MeshParts (pure VFX) |
