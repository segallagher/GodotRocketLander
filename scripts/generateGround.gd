extends MeshInstance3D

var size:float = 100.0;
var subdiv:int = 100;     # LANDING POINT MOVES BASED OFF SUBDIVISIONS THIS IS A BUG
var landingAreaMargin:int = 30;
var noiseAmp:float = 10.0;
var parent: Node3D;
var ground_mat:Material = load("res://materials/new_orm_material_3d.tres");

@onready var target_obj: Node3D = $"../Target"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent = self;
	_generate()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _generate() -> void:
	if self.mesh:
		print("MESH IS HERE ")
	
	var st = SurfaceTool.new();
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Create heightmap noise
	#var noise:Noise = FastNoiseLite.new()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	#noise.seed = randi()
	#noise.frequency = 0.05
	#noise.fractal_octaves = 4
	#noise.fractal_lacunarity = 1
	#noise.fractal_gain = 0.5
	#noise.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	
	#var noise:Noise = FastNoiseLite.new()
	#noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	#noise.seed = randi()
	#noise.frequency = 0.01
	#noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	#noise.fractal_octaves = 2
	#noise.fractal_lacunarity = 2.5
	#noise.fractal_gain = 2
	#noise.fractal_weighted_strength = 0
	
	
	var noise:Noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.015
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 3
	noise.fractal_gain = 0.5
	noise.fractal_weighted_strength = 0.4
	
	
	var noiseTexture = NoiseTexture2D.new()
	var colorRamp = Gradient.new()
	colorRamp.add_point(.2, Color(1,1,1,1))
	colorRamp.add_point(.8, Color(0,0,0,1))
	noiseTexture.color_ramp = colorRamp
	noiseTexture.noise = noise
	await noiseTexture.changed
	var image:Image = noiseTexture.get_image()
	
	
	# Get landing zone point
	var landingRange = subdiv-landingAreaMargin
	var landingPoint = Vector2(randi_range(landingAreaMargin, landingRange),randf_range(landingAreaMargin, landingRange))
	var landingRadius = 15.0
	
	# Create 2D array of points
	var stepSize = size / float(subdiv)
	var pointMatrix = []
	for x in range(subdiv + 1):
		pointMatrix.append([])
		for y in range(subdiv + 1):
			pointMatrix[x].append(	 parent.position + Vector3(x * stepSize - (size/2),
			 						_get_height(image, Vector2(x * stepSize, y * stepSize), landingPoint, landingRadius, noiseAmp),
			 						y * stepSize - (size/2))
			)
			
	# Create mesh
	for x in range(0, subdiv, 1):
		for y in range(0, subdiv, 1):
			st.add_vertex(pointMatrix[x][y])
			st.add_vertex(pointMatrix[x+1][y])
			st.add_vertex(pointMatrix[x][y+1])
			
			st.add_vertex(pointMatrix[x+1][y])
			st.add_vertex(pointMatrix[x+1][y+1])
			st.add_vertex(pointMatrix[x][y+1])
		
	st.generate_normals()
	self.mesh = st.commit()
	
	#if self.get_node("Ground_col"):
		#self.remove_child($"Ground_col")
	
	# Create Collision
	create_trimesh_collision()
	
	# Add Material
	self.mesh.surface_set_material(0, ground_mat)
	
	# Move Target model
	target_obj.position = self.position + Vector3(landingPoint.x * stepSize - (size/2), 0, landingPoint.y * stepSize - (size/2))
	target_obj.scale = Vector3(landingAreaMargin,landingAreaMargin,landingAreaMargin)
	
func _get_height(noiseImage:Image, point:Vector2,landingPoint:Vector2, landingRadius:float, amplitude:float) -> float:

	var height = noiseImage.get_pixelv(point).g * amplitude
	var distance = point.distance_to(landingPoint)
	if distance <= landingRadius:
		height = 0
	return height
