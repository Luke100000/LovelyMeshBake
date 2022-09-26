return function(renderer)
	return renderer:newModel()
				   :vertex(0, 0):uv(0, 0):color(255, 255, 255, 255):next()
				   :vertex(1, 0):uv(1, 0):color(255, 255, 255, 255):next()
				   :vertex(1, 1):uv(1, 1):color(255, 255, 255, 255):next()
				   :vertex(0, 1):uv(0, 1):color(255, 255, 255, 255):next()
				   :face()
				   :build()
end