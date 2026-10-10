local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrackGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))

local TrackBuilder = {}
-- Presentation only. Barrier thresholds/stride/offset remain geometry-owned below.
local TRACK_VISUAL_STYLE = {
	Practice = { Version = 1, KerbRows = 1, SignEvery = 12, SignText = "KDM / PRACTICE" },
	Base = { Version = 1, KerbRows = 1, SignEvery = 9, SignText = "KDM / BASE TRACK" },
	Standard = { Version = 1, KerbRows = 1, SignEvery = 6, SignText = "KDM / TECHNICAL" },
	V2B = { Version = 1, KerbRows = 2, SignEvery = 6, SignText = "KDM / V2B CANDIDATE" },
	Hard = { Version = 1, KerbRows = 2 },
}

-- Sanitized native structure from Workspace.Billboard in audited Place1.
-- Original tutorial decals/textures and all behaviors are excluded.
local PRACTICE_BILLBOARD_PARTS = {
	{ Size = Vector3.new(2.000000000, 2.000000000, 0.399999976), Frame = CFrame.new(0.000000000, 6.000000000, -4.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 13.800000191, 0.400000036), Frame = CFrame.new(6.599975586, 15.900001526, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 16.000000000, 0.200000003), Frame = CFrame.new(0.000000000, 16.000000000, -0.899993896, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.929411769, 0.917647064, 0.917647064), Shape = Enum.PartType.Block, Transparency = 0, Board = true },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(-6.600006104, 8.800003052, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(-15.600006104, 8.800003052, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(29.000000000, 3.000000000, 3.000000000), Frame = CFrame.new(0.000000000, -9.500000000, 0.000000000, 0.000000000, -1.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Cylinder, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.399999857), Frame = CFrame.new(0.000000000, 7.199996948, 2.399978638, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(31.599998474, 0.200000003, 3.599999905), Frame = CFrame.new(0.000000000, 7.309997559, -3.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.105882354, 0.164705887, 0.207843140), Shape = Enum.PartType.Block, Transparency = 0.8999999761581421, Board = false },
	{ Size = Vector3.new(0.400000006, 0.600000024, 9.399999619), Frame = CFrame.new(0.000000000, 6.699996948, 0.100006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.600000024, 9.399999619), Frame = CFrame.new(-12.000000000, 6.699996948, 0.100006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 14.599999428, 0.400000036), Frame = CFrame.new(15.400001526, 15.900001526, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.599999845), Frame = CFrame.new(0.000000000, 7.199996948, -4.699996948, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.599999428, 0.400000006), Frame = CFrame.new(0.000000000, 8.300003052, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 13.800000191, 0.400000036), Frame = CFrame.new(6.599975586, 15.900001526, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.599999905), Frame = CFrame.new(0.000000000, 7.199996948, 4.699981689, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(15.599998474, 23.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 16.000000000, 0.200000003), Frame = CFrame.new(0.000000000, 16.000000000, 0.899993896, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.929411769, 0.917647064, 0.917647064), Shape = Enum.PartType.Block, Transparency = 0, Board = true },
	{ Size = Vector3.new(32.000000000, 0.599999428, 0.400000006), Frame = CFrame.new(0.000000000, 8.300003052, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.399999857), Frame = CFrame.new(0.000000000, 7.199996948, -3.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.600000024, 9.399999619), Frame = CFrame.new(-6.000000000, 6.699996948, 0.100006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 14.600000381, 0.400000036), Frame = CFrame.new(-15.400001526, 15.900001526, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.599999428, 0.400000006), Frame = CFrame.new(0.000000000, 23.499992371, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.399999857), Frame = CFrame.new(0.000000000, 7.199996948, -2.400009155, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(31.599998474, 0.200000003, 3.599999905), Frame = CFrame.new(0.000000000, 7.309997559, 3.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.105882354, 0.164705887, 0.207843140), Shape = Enum.PartType.Block, Transparency = 0.8999999761581421, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(6.599998474, 23.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(3.000000000, 3.000000000, 3.000000000), Frame = CFrame.new(0.000000000, 6.500000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 14.600000381, 0.400000036), Frame = CFrame.new(-15.400001526, 15.900001526, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.399999857), Frame = CFrame.new(0.000000000, 7.199996948, 3.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(2.000000000, 2.000000000, 0.399999976), Frame = CFrame.new(0.000000000, 6.000000000, 4.599990845, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(15.599998474, 8.800003052, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.599999428, 0.400000006), Frame = CFrame.new(0.000000000, 23.499992371, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(8.800001144, 2.000000000, 2.000000000), Frame = CFrame.new(0.000000000, 6.000000000, -0.000015259, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 1.000000000, 0.000000000, 0.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Cylinder, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(6.599998474, 8.800003052, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(-6.600006104, 23.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.600000024, 9.399999619), Frame = CFrame.new(6.000000000, 6.699996948, 0.100006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.599999845), Frame = CFrame.new(0.000000000, 7.199996948, 1.299987793, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.400000006, 1.600000024), Frame = CFrame.new(-15.600006104, 23.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 13.800000191, 0.400000036), Frame = CFrame.new(-6.599983215, 15.900001526, -0.599975586, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 14.599999428, 0.400000036), Frame = CFrame.new(15.400001526, 15.900001526, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 13.800000191, 0.400000036), Frame = CFrame.new(-6.599983215, 15.900001526, 0.600006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(32.000000000, 0.399999976, 0.599999905), Frame = CFrame.new(0.000000000, 7.199996948, -1.300003052, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
	{ Size = Vector3.new(0.400000006, 0.600000024, 9.399999619), Frame = CFrame.new(12.000000000, 6.699996948, 0.100006104, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000, 0.000000000, 0.000000000, 0.000000000, 1.000000000), Color = Color3.new(0.733333349, 0.701960802, 0.698039234), Shape = Enum.PartType.Block, Transparency = 0, Board = false },
}

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function TrackBuilder.build(prototype: Folder, track, groundTop: number): Model
	local definition = TrackGeometry.getDefinition(track.GeometryId)
	assert(definition, "Track geometry is missing: " .. tostring(track.GeometryId))
	local isHardCircuit = track.GeometryId == "HardCircuitV1"
	local isFigure8 = track.GeometryId == "PracticeFigure8V1"
	local isV2B = track.GeometryId == "PrototypeCircuitV2B"
	local styleName = if isV2B then "V2B" elseif isHardCircuit then "Hard" elseif track.GeometryId == "PrototypeCircuitV2" then "Standard"
		elseif track.Id == "Track01Race" then "Base" else "Practice"
	local style = TRACK_VISUAL_STYLE[styleName]
	local environmentVersion = if isFigure8 then 4 elseif isHardCircuit then 6 else 1
	local previousTrack = prototype:FindFirstChild("TestTrack")
	if previousTrack and previousTrack:IsA("Model")
		and previousTrack:GetAttribute("GeometryId") == track.GeometryId
		and previousTrack:GetAttribute("TrackId") == track.Id
		and previousTrack:FindFirstChild("Road")
		and previousTrack:FindFirstChild("RaceTriggers")
		and previousTrack:FindFirstChild("BarrierTriggers")
		and previousTrack:GetAttribute("BarrierForwardTangentVersion") == 1
		and previousTrack:GetAttribute("EnvironmentCueVersion") == environmentVersion
		and previousTrack:GetAttribute("VisualStyleVersion") == style.Version
		and previousTrack:GetAttribute("VisualStyleProfile") == styleName
		and not previousTrack:FindFirstChild("BarrierCollisions")
	then
		return previousTrack
	end
	local course = TrackGeometry.getCourse(definition)
	local samples = course.Samples
	local checkpointSamples = course.CheckpointSamples
	local roadWidth = definition.RoadWidth
	local roadY = groundTop + 0.04

	local testTrack = Instance.new("Model")
	testTrack.Name = "TestTrack"
	local roadFolder = Instance.new("Folder")
	roadFolder.Name = "Road"
	roadFolder.Parent = testTrack
	local environmentFolder = Instance.new("Folder")
	environmentFolder.Name = "Environment"
	environmentFolder.Parent = testTrack
	local speedCues = Instance.new("Folder")
	speedCues.Name = "SpeedCues"
	speedCues.Parent = environmentFolder
	local markingFolder = Instance.new("Folder")
	markingFolder.Name = "Markings"
	markingFolder.Parent = testTrack
	local kerbFolder = Instance.new("Folder")
	kerbFolder.Name = "Kerbs"
	kerbFolder.Parent = testTrack
	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "Barriers"
	barrierFolder.Parent = testTrack
	local barrierTriggerFolder = Instance.new("Folder")
	barrierTriggerFolder.Name = "BarrierTriggers"
	barrierTriggerFolder.Parent = testTrack
	local markerFolder = Instance.new("Folder")
	markerFolder.Name = "Markers"
	markerFolder.Parent = testTrack
	local raceTriggerFolder = Instance.new("Folder")
	raceTriggerFolder.Name = "RaceTriggers"
	raceTriggerFolder.Parent = testTrack

	local partCount = 0
	local roadColor = Color3.fromRGB(48, 51, 56)
	local white = Color3.fromRGB(245, 245, 235)
	local kerbRed = Color3.fromRGB(205, 48, 45)
	local kerbWhite = Color3.fromRGB(238, 236, 229)
	local isPractice = track.GeometryId == "PracticeCircuitV1" or isFigure8
	local kerbThreshold = math.rad(if isPractice then 5 else 3.5)
	if isHardCircuit or isV2B then kerbThreshold = math.atan(definition.SampleSpacing / 350) end
	local barrierThreshold = math.rad(if isPractice then 7 else 9)
	if isV2B then barrierThreshold = math.atan(definition.SampleSpacing / 350) end
	local kerbCount = 0
	local barrierCount = 0
	local checkerCount = 0
	local barrierStride = if isPractice then 3 else 2

	local function roadPoint(point: Vector3, height: number): Vector3
		return Vector3.new(point.X, roadY + point.Y + height, point.Z)
	end

	local function createVisualPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
		local part = createPart(parent, name, size, cframe, color)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = material or Enum.Material.SmoothPlastic
		partCount += 1
		return part
	end

	local function createSegment(parent: Instance, name: string, first: Vector3, second: Vector3, width: number, thickness: number, overhang: number, color: Color3, material: Enum.Material?): Part
		local delta = second - first
		local midpoint = (first + second) * 0.5
		return createVisualPart(
			parent,
			name,
			Vector3.new(width, thickness, delta.Magnitude + overhang),
			CFrame.lookAt(midpoint, midpoint + delta.Unit),
			color,
			material
		)
	end

	local function directionAt(index: number): Vector3
		local previous = samples[(index - 2) % #samples + 1]
		local following = samples[index % #samples + 1]
		local delta = following - previous
		return Vector3.new(delta.X, 0, delta.Z).Unit
	end
	local function turnAt(index: number): number
		local previous = samples[(index - 2) % #samples + 1]
		local current = samples[index]
		local following = samples[index % #samples + 1]
		local arriving = (current - previous).Unit
		local leaving = (following - current).Unit
		return math.acos(math.clamp(arriving:Dot(leaving), -1, 1))
	end

	local function signedTurnAt(index: number): number
		local previous = samples[(index - 2) % #samples + 1]
		local current = samples[index]
		local following = samples[index % #samples + 1]
		local arriving = (current - previous).Unit
		local leaving = (following - current).Unit
		return arriving:Cross(leaving).Y
	end

	local function inCrossover(point: Vector3, margin: number?): boolean
		if not isFigure8 then return false end
		local crossing = definition.Crossover
		local delta = point - crossing.Position
		return Vector2.new(delta.X, delta.Z).Magnitude <= crossing.KerbClearRadius + (margin or 0)
	end

	-- Sample zero is on the long finish straight: corner runs cannot wrap the grid.
	local cornerZones = {}
	local cornerSegments = {}
	if isHardCircuit or isV2B then
		local index = 4
		while index <= #samples - 3 do
			if turnAt(index) >= kerbThreshold then
				local first = index
				local side = if signedTurnAt(index) > 0 then -1 else 1
				while index <= #samples - 3 and turnAt(index) >= kerbThreshold
					and (if signedTurnAt(index) > 0 then -1 else 1) == side do
					index += 1
				end
				-- At least one normal-speed second of connected curvature, not a spline ripple.
				if (index - first) * definition.SampleSpacing >= 70 then
					local zone = { First = first - 2, Last = index + 1, Side = side }
					table.insert(cornerZones, zone)
					for segment = zone.First, zone.Last do cornerSegments[segment] = true end
				end
			else
				index += 1
			end
		end
	end

	if isHardCircuit then
		for index = 4, #samples - 3 do
			if turnAt(index) >= kerbThreshold then cornerSegments[index] = true end
		end
	end

	local majorSegments, exitClearSegments = {}, {}
	for _, zone in cornerZones do
		for _, fraction in definition.MajorDriftFractions or {} do
			local index = fraction * #samples + 1
			if index >= zone.First and index <= zone.Last then
				for segment = zone.First, zone.Last do majorSegments[segment] = true end
				local exitFirst = math.floor(zone.First + (zone.Last - zone.First) * 0.75)
				for segment = exitFirst - 3, zone.Last + math.ceil(60 / definition.SampleSpacing) + 3 do
					exitClearSegments[segment % #samples + 1] = true
				end
			end
		end
	end

	-- Sparse, deterministic scenery gives nearby motion cues without touching
	-- the road, race triggers, barriers or kart physics.
	local speedCueObjects = 0
	local speedCueParts = 0
	local maxSpeedCueObjects = 32
	local cueStride = if isHardCircuit then 4 else math.max(7, math.ceil((#samples - 16) / maxSpeedCueObjects))
	local cueIndices = {}
	local straightCueRoles = {}
	if isHardCircuit then
		for straightIndex, straight in definition.NitroStraights or {} do
			local first = math.round(straight.StartFraction * #samples) + 1
			local last = math.round(straight.EndFraction * #samples) + 1
			for _, marker in { {first, "ENTRY"}, {first + 8, "MARKER"}, {last - 8, "MARKER"}, {last + 3, "EXIT"} } do
				table.insert(cueIndices, marker[1])
				straightCueRoles[marker[1]] = { Role = marker[2], Straight = straightIndex }
			end
		end
	end
	for index = 8, (if isFigure8 then 0 else #samples - 8), cueStride do
		if not isHardCircuit or (not cornerSegments[index] and turnAt(index) < math.rad(1)) then
			if not straightCueRoles[index] and (not isHardCircuit or #cueIndices < maxSpeedCueObjects) then table.insert(cueIndices, index) end
		end
	end
	if isHardCircuit and #cueIndices > maxSpeedCueObjects then
		local distributed = {}
		for slot = 0, maxSpeedCueObjects - 1 do
			table.insert(distributed, cueIndices[1 + math.round(slot * (#cueIndices - 1) / (maxSpeedCueObjects - 1))])
		end
		cueIndices = distributed
	end
	if isHardCircuit then table.sort(cueIndices) end
	for _, index in cueIndices do
		if speedCueObjects >= maxSpeedCueObjects then break end
		local tangent = directionAt(index)
		local side = if math.floor((index - 8) / cueStride) % 2 == 0 then 1 else -1
		local normal = Vector3.new(-tangent.Z, 0, tangent.X) * side
		local offset = roadWidth * 0.5 + 24 + (index % 3) * 5
		local center = samples[index] + normal * offset
		local clearOfRoad = not isHardCircuit or (not cornerSegments[index] and turnAt(index) < math.rad(1))
		for _, roadSample in samples do
			local delta = center - roadSample
			if Vector2.new(delta.X, delta.Z).Magnitude < roadWidth * 0.5 + 12 then
				clearOfRoad = false
				break
			end
		end
		if clearOfRoad then
			speedCueObjects += 1
			local base = roadPoint(center, 0)
			local role = straightCueRoles[index]
			local kind = if role then (if role.Role == "MARKER" then 0 else 1) else speedCueObjects % 3
			local function cuePart(name: string, size: Vector3, height: number, color: Color3, material: Enum.Material?)
				createVisualPart(speedCues, string.format("Cue%02d%s", speedCueObjects, name), size,
					CFrame.new(base + Vector3.new(0, height, 0)), color, material)
				speedCueParts += 1
			end
			if kind == 1 and (isHardCircuit or speedCueObjects % style.SignEvery == 1) then
				cuePart("SignPost", Vector3.new(1, 12, 1), 6, Color3.fromRGB(65, 73, 80), nil)
				local board = createVisualPart(speedCues, string.format("Cue%02dBillboard", speedCueObjects),
					Vector3.new(12, 6, 0.3), CFrame.lookAt(base + Vector3.new(0, 12, 0), base + Vector3.new(0, 12, 0) - normal),
					Color3.fromRGB(26, 40, 53), nil)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.CanvasSize = Vector2.new(360, 180)
				gui.Parent = board
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Text = if not isHardCircuit then style.SignText elseif role and role.Role == "ENTRY" then "KDM / NITRO " .. (if role.Straight == 1 then "A" else "B")
					elseif role and role.Role == "EXIT" then (if role.Straight == 1 then "TURN RIGHT" else "TURN LEFT")
					elseif speedCueObjects % 2 == 0 then "BOOST" else "KDM"
				label.TextScaled = true
				label.TextColor3 = white
				label.Font = Enum.Font.GothamBold
				label.Parent = gui
				speedCueParts += 1
			elseif isHardCircuit and kind == 0 then
				cuePart("Pylon", Vector3.new(2, 13, 2), 6.5, Color3.fromRGB(179, 200, 205), nil)
			elseif kind == 1 then
				cuePart("Trunk", Vector3.new(2, 12, 2), 6, Color3.fromRGB(91, 68, 49), Enum.Material.SmoothPlastic)
				cuePart("Canopy", Vector3.new(11, 12, 11), 16, Color3.fromRGB(46, 113, 65), Enum.Material.SmoothPlastic)
			elseif kind == 2 then
				cuePart("Pole", Vector3.new(1, 18, 1), 9, Color3.fromRGB(70, 78, 83), Enum.Material.SmoothPlastic)
				cuePart("Head", Vector3.new(5, 2, 3), 18, if isHardCircuit then Color3.fromRGB(255, 224, 139) else white,
					if isHardCircuit then Enum.Material.Neon else Enum.Material.SmoothPlastic)
			else
				cuePart("Rock", Vector3.new(7, 5, 6), 2.5, Color3.fromRGB(105, 111, 110), Enum.Material.Slate)
			end
		end
	end

	-- This plane only covers the gray physical ground; it cannot affect kart contact or road checks.
	local bounds = course.Bounds
	local grassMargin = if isHardCircuit then roadWidth * 0.5 + 200 else 180
	createVisualPart(
		environmentFolder, "Infield",
		Vector3.new(bounds.MaxX - bounds.MinX + grassMargin * 2, 0.02, bounds.MaxZ - bounds.MinZ + grassMargin * 2),
		CFrame.new((bounds.MinX + bounds.MaxX) * 0.5, groundTop + 0.02, (bounds.MinZ + bounds.MaxZ) * 0.5),
		Color3.fromRGB(84, 125, 79), Enum.Material.Grass
	)

	if isHardCircuit or isFigure8 or isV2B then
		local support = createPart(testTrack, "SafetyGround",
			Vector3.new(bounds.MaxX - bounds.MinX + grassMargin * 2, 1, bounds.MaxZ - bounds.MinZ + grassMargin * 2),
			CFrame.new((bounds.MinX + bounds.MaxX) * 0.5, groundTop - 0.5, (bounds.MinZ + bounds.MaxZ) * 0.5),
			Color3.fromRGB(84, 125, 79))
		support.Anchored = true
		support.CanCollide = true
		support.CanTouch = false
		support.CanQuery = true
		support.Material = Enum.Material.Grass
	end

	if isFigure8 then
		-- Same physical support/corridor authority; only the visual footprint changes.
		-- Slightly separated noncolliding ribbons hide coplanar road intersections.
		local crossing = definition.Crossover
		local guidance = Instance.new("Folder")
		guidance.Name = "CrossoverGuidance"
		guidance.Parent = markingFolder
		for branch, tangent in crossing.BranchTangents do
			local label = if branch == 1 then "A" else "B"
			local center = roadPoint(crossing.Position, 0.055 + (branch - 1) * 0.015)
			local ribbon = createVisualPart(environmentFolder, "CrossoverRibbon" .. label,
				Vector3.new(roadWidth, 0.02, crossing.VisualHalfLength * 2),
				CFrame.lookAt(center, center + tangent), roadColor, Enum.Material.Asphalt)
			ribbon:SetAttribute("CrossoverBranch", label)
			ribbon:SetAttribute("ForwardTangent", tangent)
			local right = Vector3.new(-tangent.Z, 0, tangent.X)
			for dash, distance in { -96, -72, -48, -24, 24, 48, 72, 96 } do
				local point = crossing.Position + tangent * distance
				local part = createSegment(guidance, "Branch" .. label .. "Dash" .. dash,
					roadPoint(point - tangent * 7, 0.11), roadPoint(point + tangent * 7, 0.11),
					0.8, 0.03, 0, white, nil)
				part:SetAttribute("CrossoverBranch", label)
				part:SetAttribute("BranchDistance", distance)
				part:SetAttribute("GuidanceKind", "RacingDivider")
			end
			-- Edges stop outside literal branch overlap; no kerb grid through the center.
			for _, side in { -1, 1 } do
				for _, direction in { -1, 1 } do
					local edge = crossing.Position + right * (roadWidth * 0.5 * side)
					local part = createSegment(guidance, "Branch" .. label .. "Edge" .. side .. "_" .. direction,
						roadPoint(edge + tangent * (42 * direction), 0.11),
						roadPoint(edge + tangent * (crossing.VisualHalfLength * direction), 0.11),
						1, 0.03, 0, white, nil)
					part:SetAttribute("CrossoverBranch", label)
					part:SetAttribute("GuidanceKind", "OuterEdge")
				end
			end
		end
	end

	local nextEdgeSegment = 1
	for index = 1, #samples do
		local nextIndex = index % #samples + 1
		local first = samples[index]
		local second = samples[nextIndex]
		local startBend = turnAt(index)
		local endBend = turnAt(nextIndex)
		local bend = math.max(startBend, endBend)
		local overhang = math.max(1.5, roadWidth * math.tan(bend * 0.5) + 1)
		createSegment(
			roadFolder, "Road" .. index, roadPoint(first, 0), roadPoint(second, 0),
			roadWidth, 0.05, overhang, roadColor, Enum.Material.Asphalt
		)

		local firstDirection = directionAt(index)
		local secondDirection = directionAt(nextIndex)
		local firstRight = Vector3.new(-firstDirection.Z, 0, firstDirection.X)
		local secondRight = Vector3.new(-secondDirection.Z, 0, secondDirection.X)
		local strongestTurn = if startBend >= endBend then index else nextIndex
		local innerSide = if signedTurnAt(strongestTurn) > 0 then -1 else 1
		-- Only Practice merges exactly straight edge spans; curved boundaries stay sampled.
		if not isFigure8 or index >= nextEdgeSegment then
			local last = index
			if isFigure8 and not inCrossover(first, 12) and not inCrossover(second, 12) then
				while last < math.min(index + 3, #samples - 1)
					and turnAt(last) < 0.001 and turnAt(last + 1) < 0.001
					and not inCrossover(samples[last + 2], 12) do last += 1 end
			end
			nextEdgeSegment = last + 1
			local edgeEnd = samples[last % #samples + 1]
			local endDirection = directionAt(last % #samples + 1)
			local endRight = Vector3.new(-endDirection.Z, 0, endDirection.X)
			for _, side in { -1, 1 } do
				if inCrossover(first, 12) or inCrossover(edgeEnd, 12) then continue end
				createSegment(markingFolder, (if side < 0 then "LeftEdge" else "RightEdge") .. index,
					roadPoint(first + firstRight * (roadWidth * 0.5 * side), 0.04),
					roadPoint(edgeEnd + endRight * (roadWidth * 0.5 * side), 0.04),
					1, 0.035, 0.6, white, nil)
			end
		end

		-- Leave the grid and finish crossing visually open. Corner strips sit beyond the road edge.
		local nearStart = index <= 3 or index >= #samples - 2
		-- Legacy bend threshold remains the corner cue; the common single band
		-- continues along both edges, merging gentle spans to bound mobile parts.
		if not isHardCircuit and not nearStart and bend >= kerbThreshold then cornerSegments[index] = true end

		if not isFigure8 and not nearStart and bend >= barrierThreshold and index % barrierStride == 0
			and not exitClearSegments[index] then
			local outerSide = -innerSide
			-- B-only starting probe; certified against actual Road boxes after all roads exist.
			local offset = roadWidth * 0.5 + (if isV2B then 34 elseif isHardCircuit then (if majorSegments[index] then 28 else 22) else 7)
			local firstBarrier = first + firstRight * (offset * outerSide)
			local secondBarrier = second + secondRight * (offset * outerSide)
			local barrierY = groundTop + 1.23
			local barrier = createSegment(
				barrierFolder, "Barrier" .. index,
				Vector3.new(firstBarrier.X, barrierY, firstBarrier.Z),
				Vector3.new(secondBarrier.X, barrierY, secondBarrier.Z),
				1.6, 2.4, 0.2,
				if index % (barrierStride * 2) == 0 then kerbRed else kerbWhite, nil
			)
			local roadMidpoint = (first + second) * 0.5
			local toRoad = roadMidpoint - barrier.Position
			local inwardNormal = Vector3.new(toRoad.X, 0, toRoad.Z).Unit
			local trigger = createPart(
				barrierTriggerFolder, "BarrierTrigger" .. index,
				Vector3.new(5, barrier.Size.Y, barrier.Size.Z + 2),
				barrier.CFrame + inwardNormal * 2, barrier.Color
			)
			trigger.Anchored = true
			trigger.Transparency = 1
			trigger.CanCollide = false
			trigger.CanTouch = false
			trigger.CanQuery = false
			trigger.CastShadow = false
			trigger:SetAttribute("BarrierInwardNormal", inwardNormal)
			local segmentDelta = second - first
			trigger:SetAttribute("BarrierForwardTangent", Vector3.new(segmentDelta.X, 0, segmentDelta.Z).Unit)
			trigger:SetAttribute("BarrierIndex", index)
			barrierCount += 1
		end

		if index % 3 == 1 and not inCrossover(first, 12) and not inCrossover(second, 12) then
			createSegment(
				markingFolder, "CenterDash" .. index,
				roadPoint(first:Lerp(second, 0.22), 0.04),
				roadPoint(first:Lerp(second, 0.78), 0.04),
				0.8, 0.03, 0, white, nil
			)
		end
	end

	if isV2B then
		-- Certify BOTH visible rails and logical triggers against every rendered road.
		-- A nearby other branch can invalidate an otherwise generous outer offset.
		local function quad(part: BasePart)
			local center, right, forward = part.Position, part.CFrame.RightVector, part.CFrame.LookVector
			local result = {}
			for _, corner in { {-1, -1}, {-1, 1}, {1, 1}, {1, -1} } do
				local p = center + right * (corner[1] * part.Size.X * 0.5)
					+ forward * (corner[2] * part.Size.Z * 0.5)
				table.insert(result, Vector2.new(p.X, p.Z))
			end
			return result
		end
		local function distance(point, first, last)
			local edge = last - first
			return (point - first - edge * math.clamp((point - first):Dot(edge) / edge:Dot(edge), 0, 1)).Magnitude
		end
		local function gap(a, b)
			local separated = false
			for _, polygon in {a, b} do
				for i, point in polygon do
					local edge = polygon[i % 4 + 1] - point
					local axis = Vector2.new(-edge.Y, edge.X)
					local lowA, highA, lowB, highB = math.huge, -math.huge, math.huge, -math.huge
					for _, p in a do local v = p:Dot(axis); lowA = math.min(lowA, v); highA = math.max(highA, v) end
					for _, p in b do local v = p:Dot(axis); lowB = math.min(lowB, v); highB = math.max(highB, v) end
					if highA < lowB or highB < lowA then separated = true end
				end
			end
			if not separated then return 0 end
			local minimum = math.huge
			for i, p in a do
				for j, q in b do
					minimum = math.min(minimum, distance(p, q, b[j % 4 + 1]), distance(q, p, a[i % 4 + 1]))
				end
			end
			return minimum
		end
		local roads = {}
		for _, road in roadFolder:GetChildren() do table.insert(roads, { Part = road, Quad = quad(road) }) end
		local omitted, minimum = 0, math.huge
		for _, trigger in barrierTriggerFolder:GetChildren() do
			local rail = barrierFolder:FindFirstChild("Barrier" .. trigger:GetAttribute("BarrierIndex"))
			local triggerQuad, railQuad = quad(trigger), quad(rail)
			local clearance = math.huge
			for _, road in roads do
				local delta = road.Part.Position - trigger.Position
				local reach = road.Part.Size.Magnitude * 0.5 + trigger.Size.Magnitude * 0.5 + 22
				if Vector2.new(delta.X, delta.Z).Magnitude <= reach then
					clearance = math.min(clearance, gap(triggerQuad, road.Quad), gap(railQuad, road.Quad))
				end
			end
			-- Conservative 18 everywhere also covers normal12 and major16.
			if clearance < 18 then
				trigger:Destroy(); rail:Destroy(); barrierCount -= 1; partCount -= 1; omitted += 1
			else
				minimum = math.min(minimum, clearance)
				trigger:SetAttribute("MinimumRoadClearance", clearance)
				trigger:SetAttribute("RequiredRoadClearance", 18)
			end
		end
		testTrack:SetAttribute("V2BSafetyOmittedBarrierCount", omitted)
		testTrack:SetAttribute("V2BMinimumBarrierClearance", if minimum < math.huge then minimum else 0)
	end

	local singleKerbParts, doubleKerbParts, sharpGroupCount = 0, 0, 0
	local doubleSegments = {}
	if isHardCircuit or isFigure8 or isV2B then
		-- A sustained <=105-stud core enters the thick kerb band; <=140 holds it
		-- through the shoulder of the bend. Ignore isolated one/two-sample spikes.
		local sharpCore = math.atan(definition.SampleSpacing / 105)
		local sharpHold = math.atan(definition.SampleSpacing / 140)
		local index = 4
		while index <= #samples - 3 do
			if turnAt(index) >= sharpCore then
				local first = index
				while index <= #samples - 3 and turnAt(index) >= sharpCore do index += 1 end
				if index - first >= 3 then
					local last = index - 1
					while first > 4 and turnAt(first - 1) >= sharpHold do first -= 1 end
					while last < #samples - 3 and turnAt(last + 1) >= sharpHold do last += 1 end
					for segment = first - 2, last + 2 do doubleSegments[segment] = true end
				end
			else index += 1 end
		end
		for segment = 2, #samples - 1 do
			if doubleSegments[segment] and not doubleSegments[segment - 1] then sharpGroupCount += 1 end
		end
	end
	-- Hard retains its exact band algorithm; standard profiles use only row one.
	do
		local function edgeAt(index: number, offset: number, side: number): Vector3
			local tangent = directionAt(index)
			return samples[(index - 1) % #samples + 1] + Vector3.new(-tangent.Z, 0, tangent.X) * offset * side
		end
		local function chordError(first: number, last: number, offset: number, side: number): number
			local a, b = edgeAt(first, offset, side), edgeAt(last + 1, offset, side)
			local delta = b - a
			local error = 0
			for step = first + 1, last do
				local point = edgeAt(step, offset, side)
				local alpha = math.clamp((point - a):Dot(delta) / delta:Dot(delta), 0, 1)
				error = math.max(error, (point - a - delta * alpha).Magnitude)
			end
			return error
		end
		for row = 1, (if isFigure8 then 2 else style.KerbRows) do
			local offset = roadWidth * 0.5 + 2.6 + (row - 1) * 3.6
			local segment, stripe = (if isFigure8 then 1 else 2), 0
			local lastAllowed = if isFigure8 then #samples else #samples - 1
			while segment <= lastAllowed do
				if inCrossover(samples[segment], 12) or inCrossover(samples[segment % #samples + 1], 12) then segment += 1; continue end
				if row == 2 and not doubleSegments[segment] then segment += 1; continue end
				local last = segment
				-- Merge only gentle spans within 0.25 stud of BOTH true offset edges.
				while last < math.min(segment + 3, lastAllowed)
					and (row == 1 or doubleSegments[last + 1])
					and not inCrossover(samples[(last + 1) % #samples + 1], 12)
					and not inCrossover(samples[(last + 2) % #samples + 1], 12)
					and turnAt(last + 1) < math.atan(definition.SampleSpacing / 250)
					and chordError(segment, last + 1, offset, -1) <= 0.25
					and chordError(segment, last + 1, offset, 1) <= 0.25 do last += 1 end
				stripe += 1
				for _, side in { -1, 1 } do
					if isV2B and row == 2 then
						-- The inherited tight P15 apex cannot support a second inner offset row.
						-- Keep the continuous first row and outward sharp-corner band.
						local foldsInnerRow = false
						for step = segment, last + 1 do
							local before, point, after = samples[(step - 2) % #samples + 1], samples[(step - 1) % #samples + 1], samples[step % #samples + 1]
							local a, b = point - before, after - point
							local cross = a:Cross(b)
							if cross.Y * side < 0 and cross.Magnitude > 0.000001 then
								local radius = a.Magnitude * b.Magnitude * (a + b).Magnitude / (2 * cross.Magnitude)
								if radius <= offset + 2 then foldsInnerRow = true end
							end
						end
						if foldsInnerRow then continue end
					end
					local part = createSegment(kerbFolder,
						(if side < 0 then "LeftKerb" else "RightKerb") .. "Row" .. row .. "_" .. segment,
						roadPoint(edgeAt(segment, offset, side), 0.025), roadPoint(edgeAt(last + 1, offset, side), 0.025),
						3.5, 0.07, 1.6, if stripe % 2 == 0 then kerbRed else kerbWhite, nil)
					part:SetAttribute("KerbRow", row)
					part:SetAttribute("KerbSide", side)
					part:SetAttribute("FirstSegment", segment)
					part:SetAttribute("LastSegment", last)
					if row == 1 then singleKerbParts += 1 else doubleKerbParts += 1 end
					kerbCount += 1
				end
				segment = last + 1
			end
		end
	end

	local chevronParts = 0
	local chevronClusters = 0
	if isHardCircuit or isFigure8 or isV2B then
		local directions = Instance.new("Folder")
		directions.Name = "DirectionMarkers"
		directions.Parent = testTrack
		local traveled = 0
		local nextMarker = 70 -- Initial forward cue shortly after the checker/grid.
		for index = 2, #samples - 2 do
			traveled += (samples[index] - samples[index - 1]).Magnitude
			if traveled < nextMarker then continue end
			local clearOfGate = (samples[index] - course.StartPosition).Magnitude > 28
			for _, checkpoint in checkpointSamples do
				if (samples[index] - checkpoint.Position).Magnitude < 28 then clearOfGate = false end
			end
			if not clearOfGate or inCrossover(samples[index], if isFigure8 then 98 else 45) then continue end
			local tangent = directionAt(index)
			local right = Vector3.new(-tangent.Z, 0, tangent.X)
			for _, laneSide in { -1, 1 } do
				chevronClusters += 1
				local origin = roadPoint(samples[index] + right * (roadWidth * 0.25 * laneSide), 0.12)
				local cluster = Instance.new("Folder")
				cluster.Name = "ForwardChevron" .. chevronClusters
				cluster:SetAttribute("SampleIndex", index)
				cluster:SetAttribute("LaneSide", laneSide)
				cluster.Parent = directions
				-- Same forward cue in each lane center; keep the center divider clear.
				for arrow = -1, 1 do
					for _, wing in { -1, 1 } do
						local head = origin + tangent * (arrow * 8 + 3)
						local tail = origin + tangent * (arrow * 8 - 3) + right * (wing * 3)
						createSegment(cluster, "Arrow" .. arrow .. "Wing" .. wing, tail, head, 1.1, 0.035, 0,
							Color3.fromRGB(185, 202, 204), nil)
						chevronParts += 1
					end
				end
			end

			nextMarker = traveled + (if cornerSegments[index] then 98 else 154)
		end
	end

	if isFigure8 then
		local directions = testTrack:FindFirstChild("DirectionMarkers")
		local crossing = definition.Crossover
		for branch, tangent in crossing.BranchTangents do
			local right = Vector3.new(-tangent.Z, 0, tangent.X)
			for _, distance in { -118, 118 } do
				for _, lane in { -1, 1 } do
					local origin = crossing.Position + tangent * distance + right * (roadWidth * 0.25 * lane)
					local cluster = Instance.new("Folder")
					cluster.Name = "CrossoverChevron" .. branch .. "_" .. distance .. "_" .. lane
					cluster:SetAttribute("ForwardTangent", tangent)
					cluster:SetAttribute("CrossoverBranch", branch)
					cluster:SetAttribute("BranchDistance", distance)
					cluster:SetAttribute("LaneSide", lane)
					cluster.Parent = directions
					for _, wing in { -1, 1 } do
						createSegment(cluster, "Wing" .. wing,
							roadPoint(origin - tangent * 3 + right * (wing * 3), 0.12),
							roadPoint(origin + tangent * 3, 0.12), 1.1, 0.035, 0,
							Color3.fromRGB(185, 202, 204), nil)
						chevronParts += 1
					end
					chevronClusters += 1
				end
			end
		end
	end

	if isFigure8 then
		local decor = Instance.new("Folder")
		decor.Name = "PracticeLandmarks"
		decor.Parent = environmentFolder
		local billboardFraction = 0.42
		local tangent = TrackGeometry.getTangentAtFraction(samples, billboardFraction)
		local normal = Vector3.new(-tangent.Z, 0, tangent.X)
		local billboardCenter = TrackGeometry.getSampleAtFraction(samples, billboardFraction) + normal * 88
		local mount = CFrame.lookAt(roadPoint(billboardCenter, 24), roadPoint(billboardCenter - normal, 24))
		local billboard = Instance.new("Model")
		billboard.Name = "KDMDriftPracticeBillboard"
		billboard.Parent = decor
		for index, spec in PRACTICE_BILLBOARD_PARTS do
			local part = createVisualPart(billboard, "Structure" .. index, spec.Size, mount * spec.Frame,
				if spec.Board then Color3.fromRGB(26, 40, 53) else spec.Color, Enum.Material.SmoothPlastic)
			part.Shape = spec.Shape
			part.Transparency = spec.Transparency
			if spec.Board then
				for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
					local gui = Instance.new("SurfaceGui")
					gui.Face = face
					gui.CanvasSize = Vector2.new(640, 320)
					gui.Parent = part
					local label = Instance.new("TextLabel")
					label.Size = UDim2.fromScale(1, 1)
					label.BackgroundTransparency = 1
					label.Text = "KDM\nDRIFT PRACTICE"
					label.TextScaled = true
					label.TextColor3 = Color3.fromRGB(0, 196, 224)
					label.Font = Enum.Font.GothamBold
					label.Parent = gui
				end
			end
		end
		local trees = 0
		for _, fraction in { .09, .16, .22, .31, .36, .41, .60, .66, .70, .77, .81, .85, .27, .55, .95, .04 } do
			if trees >= 12 then break end
			local point = TrackGeometry.getSampleAtFraction(samples, fraction)
			local forward = TrackGeometry.getTangentAtFraction(samples, fraction)
			local right = Vector3.new(-forward.Z, 0, forward.X)
			local a = TrackGeometry.getTangentAtFraction(samples, fraction - .005)
			local b = TrackGeometry.getTangentAtFraction(samples, fraction + .005)
			local preferred = if a:Cross(b).Y > 0 then 1 else -1
			for _, side in { preferred, -preferred } do
				local center = point + right * (78 * side)
				local clear = not inCrossover(center, 55) and (center - billboardCenter).Magnitude > 55
				for _, roadSample in samples do
					if (center - roadSample).Magnitude < 62 then clear = false; break end
				end
				if not clear then continue end
				trees += 1
				local tree = Instance.new("Model")
				tree.Name = "PracticePine" .. trees
				tree.Parent = decor
				-- Audited PineTree trunk dimensions/colors, with three native canopy
				-- tiers replacing its 44 nonportable UnionOperations. No donor mesh.
				createVisualPart(tree, "Trunk", Vector3.new(2, 34, 2), CFrame.new(roadPoint(center, 17)),
					Color3.fromRGB(108, 88, 75), Enum.Material.SmoothPlastic)
				for tier, spec in { {18, 22}, {14, 28}, {10, 34} } do
					createVisualPart(tree, "Canopy" .. tier, Vector3.new(spec[1], 7, spec[1]),
						CFrame.new(roadPoint(center, spec[2])), Color3.fromRGB(80, 109, 84), Enum.Material.SmoothPlastic)
				end
				break
			end
		end
		testTrack:SetAttribute("PracticeTreeCount", trees)
		testTrack:SetAttribute("PracticeBillboardPartCount", #PRACTICE_BILLBOARD_PARTS)
		testTrack:SetAttribute("PracticeSignalPartCount", 0)
	end

	local function createRaceGate(name: string, point: Vector3, direction: Vector3, gateType: string, checkpointIndex: number?)
		local gatePosition = Vector3.new(point.X, groundTop + 8, point.Z)
		local planarDirection = Vector3.new(direction.X, 0, direction.Z).Unit
		local gate = createPart(
			raceTriggerFolder, name, Vector3.new(roadWidth + 20, 20, 20),
			CFrame.lookAt(gatePosition, gatePosition + planarDirection), Color3.new(1, 1, 1)
		)
		gate.Anchored = true
		gate.CanCollide = false
		gate.CanTouch = false
		gate.CanQuery = false
		gate.Transparency = 1
		gate:SetAttribute("RaceGate", true)
		gate:SetAttribute("GateType", gateType)
		if checkpointIndex then
			gate:SetAttribute("CheckpointIndex", checkpointIndex)
		end
	end

	local startPoint = course.StartPosition
	local startDirection = course.StartTangent
	local startCFrame = CFrame.lookAt(roadPoint(startPoint, 0.058), roadPoint(startPoint + startDirection, 0.058))
	local checkerColumns = 10
	local checkerRows = 2
	for row = 1, checkerRows do
		for column = 1, checkerColumns do
			local offsetX = (column - 0.5 - checkerColumns * 0.5) * roadWidth / checkerColumns
			local offsetZ = (row - 0.5 - checkerRows * 0.5) * 3 / checkerRows
			createVisualPart(
				markingFolder, "StartLine" .. row .. "_" .. column,
				Vector3.new(roadWidth / checkerColumns, 0.035, 3 / checkerRows),
				startCFrame * CFrame.new(offsetX, 0, offsetZ),
				if (row + column) % 2 == 0 then Color3.fromRGB(20, 22, 24) else white, nil
			)
			checkerCount += 1
		end
	end
	createRaceGate("StartFinish", startPoint, startDirection, "StartFinish", nil)
	for index, checkpoint in checkpointSamples do
		createRaceGate(
			"Checkpoint" .. index,
			checkpoint.Position,
			checkpoint.Tangent,
			"Checkpoint", index
		)
	end

	testTrack:SetAttribute("GeometryId", track.GeometryId)
	testTrack:SetAttribute("TrackId", track.Id)
	testTrack:SetAttribute("VisualStyleProfile", styleName)
	testTrack:SetAttribute("VisualStyleVersion", style.Version)
	testTrack:SetAttribute("VisualPartCount", partCount)
	testTrack:SetAttribute("EnvironmentPartCount", 1 + speedCueParts + (if isFigure8 then 2 + #PRACTICE_BILLBOARD_PARTS + (testTrack:GetAttribute("PracticeTreeCount") or 0) * 4 else 0))
	testTrack:SetAttribute("EnvironmentCueVersion", environmentVersion)
	if isHardCircuit or isFigure8 or isV2B then
		testTrack:SetAttribute("CornerZoneCount", #cornerZones)
		testTrack:SetAttribute("SingleKerbPartCount", singleKerbParts)
		testTrack:SetAttribute("DoubleKerbPartCount", doubleKerbParts)
		testTrack:SetAttribute("SharpKerbGroupCount", sharpGroupCount)
		testTrack:SetAttribute("ChevronClusterCount", chevronClusters)
		testTrack:SetAttribute("ChevronPartCount", chevronParts)
	end
	testTrack:SetAttribute("SpeedCueObjectCount", speedCueObjects)
	testTrack:SetAttribute("SpeedCuePartCount", speedCueParts)
	testTrack:SetAttribute("KerbPartCount", kerbCount)
	testTrack:SetAttribute("BarrierPartCount", barrierCount)
	testTrack:SetAttribute("BarrierTriggerPartCount", barrierCount)
	testTrack:SetAttribute("BarrierForwardTangentVersion", 1)
	testTrack:SetAttribute("CheckerPartCount", checkerCount)
	testTrack:SetAttribute("CheckpointCount", #checkpointSamples)
	testTrack:SetAttribute("CenterlineLength", course.CenterlineLength)
	testTrack:SetAttribute("CenterlineSampleCount", #samples)
	testTrack:SetAttribute("RoadSegmentCount", #samples)
	testTrack:SetAttribute("RoadWidth", roadWidth)
	if previousTrack then
		previousTrack:Destroy()
	end
	testTrack.Parent = prototype
	return testTrack
end

return TrackBuilder
