# Desert mesh and one-human bot Rematch correction

Production v1134 had three Natural MeshPart templates with MeshId empty and
MeshContent.SourceType=None. SurfaceAppearance/TextureID still existed, creating
textured boxes; staging retained all three original MeshIds. Repo XML and Rojo
release XML contain correct IDs, so code/asset presence and compiled counts did
not establish the serialized live Studio mesh state. This was missed in the
previous visual review.

Rebuilt actual production prefab geometry with AssetService.CreateMeshPartAsync
and ApplyMesh in Edit mode, preserving size,frame,texture and SurfaceAppearance.
Added tools/repair_desert_mesh_prefabs.luau as an explicit authoring pre-Publish
gate. No runtime mesh download/construction. Client refuses an empty-mesh prefab
rather than displaying a misleading textured bounding box.

The Rematch logic and highlighted result label were present, but intentionally
required >=2 humans. Owner now explicitly approved one human plus bot as well.
Session continuation, official result submission and reducer validation accept
that frozen roster. Solo without an opponent is still excluded. Base prizes are
unchanged (one-human bot base1500), PB/event bonuses stay unmultiplied; only rank
base is multiplied. Next result banner shows multiplier only, no future amount.

Validation:150 session/reducer/receipt checks including bot x2/x3/x4 and no double
payment;282076 source/desert checks;65 official-record checks;13 warm-up observer
checks;222 production sources compile;Rojo release XML;diff check PASS.
Production-bound Studio ordinary client startup created106 MeshParts,0 empty
MeshIds. Native screenshot confirms proper rock/cactus/agave silhouettes. Actual
session-owned test attributes show NEXT REMATCH REWARD X2 and X4 within result
panel. Result UI was exercised with synthetic finish state; this is not a newly
driven full lap or a live payment verification. QA startup restored before
Publish; no temporary QA scene/scripts included.
