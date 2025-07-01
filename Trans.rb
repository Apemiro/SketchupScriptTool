#一些有关变换的函数
module Trans

	Iden=Geom::Transformation.new unless defined?(Iden)
	MovX=Geom::Transformation.translation([1,0,0]) unless defined?(MovX)
	MovY=Geom::Transformation.translation([0,1,0]) unless defined?(MovY)
	MovZ=Geom::Transformation.translation([0,0,1]) unless defined?(MovZ)
	
	def self.tx(dist) Geom::Transformation.translation([dist,0,0]) end
	def self.ty(dist) Geom::Transformation.translation([0,dist,0]) end
	def self.tz(dist) Geom::Transformation.translation([0,0,dist]) end
	
	module ViewDraw
		def self.circle_points(center,normal,radius,segment=24)
			raise ArgumentError.new("段数小于3") if segment<3
			cen=Geom::Point3d.new(center)
			nor=Geom::Vector3d.new(normal)
			if nor.parallel?([0,0,1]) then
				rdv=nor+[0,1,0]
			else
				rdv=nor+[0,0,1]
			end
			fir=nor.cross(rdv)
			fir.length=radius
			fir=cen+fir
			ang=360.degrees/segment
			res=[fir]
			1.upto(segment-1){|i|
				res.push(fir.transform(Geom::Transformation.rotation(cen,normal,i*ang)))
			}
			res
		end
	end
	
	module Reduction
		def self.triangle_area(p1,p2,p3)
			a=(p1-p2).length.abs
			b=(p2-p3).length.abs
			c=(p3-p1).length.abs
			p=a+b+c
			p/=2.0
			return p*(p-a)*(p-b)*(p-c)
		end
		def self.triangle_cog(points)
			xx,yy,zz=0,0,0
			points.each{|i|
				xx+=i.x
				yy+=i.y
				zz+=i.z
			}
			return [xx/3.0,yy/3.0,zz/3.0]
		end
		#平面的重心，通过三角形网络合并，精度似乎有一点问题
		def self.centroid(face)
			return nil unless face.is_a?(Sketchup::Face)
			mesh=face.mesh
			cgs=[]
			1.upto(mesh.count_polygons) do |i|
				idx=mesh.polygon_at(i)
				pos=idx.map{|i|mesh.point_at(i)}
				cgs<<[triangle_area(*pos),triangle_cog(pos)]
			end
			while cgs.length>1 do
				toto=cgs[0][0]+cgs[1][0]
				w1=cgs[0][0]/toto
				w2=cgs[1][0]/toto
				p1=cgs[0][1]
				p2=cgs[1][1]
				ncg=Geom.linear_combination(w1,p1,w2,p2)
				cgs[0]=[toto,ncg]
				cgs.delete_at(1)
			end
			return Geom::Point3d.new(cgs[0][1])
		end
		def self.centroid_circle(face,seg=24)
			center=centroid(face)
			radius=Math.sqrt(face.area/Math::PI)
			normal=face.normal
			g=face.parent.entities.add_group
			g.definition.entities.add_circle(center,normal,radius,seg)
		end
	end

	module Rand
		def self.rotation2D(ent)
			center=ent.bounds.center
			angle=rand()*360.degrees
			normal=[0,0,1]
			t=Geom::Transformation.rotation(center,normal,angle)
			Sketchup.active_model.entities.transform_entities(t,ent)
		end
		def self.movement2D(ent,max_radius=1000.mm)
			angle=rand()*360.degrees
			radius=rand()*max_radius
			vector=Geom::Vector3d.new(radius,0,0)
			tmp=Geom::Transformation.rotation([0,0,0],[0,0,1],angle)
			vector.transform!(tmp)
			t=Geom::Transformation.translation(vector)
			Sketchup.active_model.entities.transform_entities(t,ent)
		end
		def self.random_vector()
			result=Geom::Vector3d.new(1,0,0)
			normal=Geom::Vector3d.new(0,1,0)
			phi=rand()*360.degrees
			theta=rand()*360.degrees
			th=Geom::Transformation.rotation([0,0,0],[0,0,1],phi)
			normal.transform!(th)
			t=Geom::Transformation.rotation([0,0,0],normal,theta)
			return result.transform(th*t)
		end	
		private_class_method :random_vector
		def self.rotation3D(ent)
			center=ent.bounds.center
			vector=random_vector()
			angle=rand()*360.degrees
			t=Geom::Transformation.rotation(center,vector,angle)
			Sketchup.active_model.entities.transform_entities(t,ent)
		end
		def self.movement3D(ent,max_radius=1000.mm)
			vector=random_vector()
			radius=rand()*max_radius
			vector.length=radius
			t=Geom::Transformation.translation(vector)
			Sketchup.active_model.entities.transform_entities(t,ent)
		end
		def self.scaling(ent,range)
			raise ArgumentError.new("Range expected but #{range.class} found.") unless range.is_a?(Range)
			centre=ent.bounds.center
			factor=range.begin+(range.end-range.begin)*rand
			trans=Geom::Transformation.scaling(centre,*[factor]*3)
			Sketchup.active_model.entities.transform_entities(trans,ent)
		end
		
		
		
		def self.action(action_name,arr,&block)
			arr=Sketchup.active_model.selection.to_a if arr.nil?
			arr=[arr] unless arr.respond_to?(:[])
			Sketchup.active_model.start_operation(action_name,true)
			arr.each{|ent|
				block.call(ent)
			}
			Sketchup.active_model.commit_operation
		end
		private_class_method :action
		
		def self.r2d(arr=nil) action("Apiglio Trans: 水平面随机旋转",arr){|e|rotation2D(e)} end
		def self.r3d(arr=nil) action("Apiglio Trans: 三维随机旋转",arr){|e|rotation3D(e)} end
		def self.m2d(dist,arr=nil) action("Apiglio Trans: 水平面随机平移",arr){|e|movement2D(e,dist)} end
		def self.m3d(dist,arr=nil) action("Apiglio Trans: 三维随机平移",arr){|e|movement3D(e,dist)} end
		def self.sca(range,arr=nil) action("Apiglio Trans: 随机等比例缩放",arr){|e|scaling(e,range)} end
		
		module MoranScatter
			require 'matrix'
			def self.distance(p1, p2)
				Math.sqrt((p1[0] - p2[0])**2 + (p1[1] - p2[1])**2)
			end
			def self.morans_i(points, bbox_width, bbox_height)
				n = points.size
				return 0.0 if n <= 1
				mean = points.map { |p| p[2] }.sum / n.to_f                 # 计算均值
				variance = points.map { |p| (p[2] - mean)**2 }.sum / n.to_f # 计算方差
				return 0.0 if variance.zero?
				# 计算空间权重矩阵（基于距离倒数）
				weights = Array.new(n) { Array.new(n, 0.0) }
				sum_weights = 0.0
				(0...n).each do |i|
					(0...n).each do |j|
						next if i == j
						d = self.distance(points[i], points[j])
						weights[i][j] = 1.0 / (d + 1e-6)  # 避免除零
						sum_weights += weights[i][j]
					end
				end
				numerator = 0.0
				(0...n).each do |i|
					(0...n).each do |j|
						next if i == j
						numerator += weights[i][j] * (points[i][2] - mean) * (points[j][2] - mean)
					end
				end
				moran_i = (n / sum_weights) * (numerator / (n * variance))
				moran_i
			end
			def self.enforce_min_spacing(points, min_spacing)
				new_points = points.dup
				n = new_points.size
				(0...n).each do |i|
					(i+1...n).each do |j|
						d = self.distance(new_points[i], new_points[j])
						next if d >= min_spacing
						# 移动点i和点j以增加间距
						dx = new_points[j][0] - new_points[i][0]
						dy = new_points[j][1] - new_points[i][1]
						angle = Math.atan2(dy, dx)
						move_dist = (min_spacing - d) / 2.0
						# 更新坐标（避免越界）
						new_points[i][0] -= move_dist * Math.cos(angle)
						new_points[i][1] -= move_dist * Math.sin(angle)
						new_points[j][0] += move_dist * Math.cos(angle)
						new_points[j][1] += move_dist * Math.sin(angle)
						# 限制在边界内（假设边界为[0,1]x[0,1]）
						new_points[i][0] = [0.0, [1.0, new_points[i][0]].min].max
						new_points[i][1] = [0.0, [1.0, new_points[i][1]].min].max
						new_points[j][0] = [0.0, [1.0, new_points[j][0]].min].max
						new_points[j][1] = [0.0, [1.0, new_points[j][1]].min].max
					end
				end
				new_points
			end
			def self.generate_points(target_moran_i, density, min_spacing, max_iter=1000, tolerance=0.01)
				# 初始化参数
				bbox_width = 1.0  # 假设空间范围为[0,1]x[0,1]
				bbox_height = 1.0
				n_points = (density * bbox_width * bbox_height).to_i
				points = []
				# 初始随机分布（假设属性值为随机数）
				n_points.times do
					x = rand
					y = rand
					value = rand  # 假设属性值（用于计算莫兰指数）
					points << [x, y, value]
				end
				# 迭代优化
				max_iter.times do |iter|
					current_moran_i = self.morans_i(points, bbox_width, bbox_height) # 检查是否收敛
					break if (current_moran_i - target_moran_i).abs < tolerance # 调整点分布（简化版：根据莫兰指数差异移动点）
					points.each do |point|
					if current_moran_i < target_moran_i
						# 需要更聚集，随机选择一个邻近点向中心移动
						point[0] += (0.5 - point[0]) * 0.1
						point[1] += (0.5 - point[1]) * 0.1
					else
						# 需要更离散，随机远离中心
						point[0] += (point[0] - 0.5) * 0.1
						point[1] += (point[1] - 0.5) * 0.1
					end
						# 限制在边界内
						point[0] = [0.0, [1.0, point[0]].min].max
						point[1] = [0.0, [1.0, point[1]].min].max
					end
					# 强制最小间距约束
					points = self.enforce_min_spacing(points, min_spacing)
				end
				points.map { |p| [p[0], p[1]] }
			end
			private_class_method :distance, :morans_i, :enforce_min_spacing, :generate_points
			def self.place_instances_on_ground(component_defintion, trans, target_moran_i, density, min_spacing, max_iter=1000, tolerance=0.01)
				points = self.generate_points(target_moran_i, density, min_spacing, max_iter, tolerance)
				points.each{|point|
					Sketchup.active_model.entities.add_instance(component_defintion, trans*Geom::Transformation.translation(point+[0]))
				}
			end
			# 调用示例
			# target_moran_i = 0.3  # 目标莫兰指数
			# density = 20          # 点密度（点数/单位面积）
			# min_spacing = 0.05    # 最小间距
			# points = generate_points(target_moran_i, density, min_spacing)
			# puts "Generated points:"
			# points.each { |p| puts "(#{p[0].round(3)}, #{p[1].round(3)})" }
		end
		
	end
	
	module Curve
		#三点弧的代码版本
		def self.add_arc_3point(*arg)
			if arg.length==3 then pts=arg.to_a else
				if arg[0].is_a? Array then pts=arg[0].to_a
				else raise ArgumentError.new("3 Point3 Required.") end
			end

			pos=pts.map{|p|Geom::Point3d.new(p)}
			v1=pos[0]-pos[1];v2=pos[2]-pos[1]
			v1.length=v1.length/2
			v2.length=v2.length/2
			m1=pos[1]+v1;m2=pos[1]+v2

			plane=Geom.fit_plane_to_points(pos)
			normal=Geom.intersect_plane_plane([m1,v1],[m2,v2])
			center=Geom.intersect_line_plane(normal,plane)
			radius=center.distance(pos[0])

			vector_0=pos[0]-center
			vector_1=pos[1]-center
			vector_2=pos[2]-center
			ang01=vector_0.angle_between(vector_1)
			ang02=vector_0.angle_between(vector_2)
			ang12=vector_1.angle_between(vector_2)

			if (ang02-(ang01+ang12)).abs<0.000001 then
				normal[1].reverse! unless normal[1].samedirection?(vector_1*vector_2)
				ea=ang02
			else
				ea=2*Math::PI-ang02
				if (ang01-(ang12+ang02)).abs<0.000001 then
					normal[1].reverse! unless normal[1].samedirection?(vector_1*vector_2)
				else
					normal[1].reverse! unless normal[1].samedirection?(vector_0*vector_1)
				end
			end

			Sketchup.active_model.entities.add_arc(center,vector_0,normal[1],radius,0,ea)
			return nil
		end
		
		#两点弧的代码版本
		def self.add_arc_2point(pt1,pt2,vec)
			raise ArgumentError.new("Point3d or Array required.") unless pt1.respond_to?(:on_line?)
			raise ArgumentError.new("Point3d or Array required.") unless pt2.respond_to?(:on_line?)
			raise ArgumentError.new("Vector3d or Array required.") unless vec.respond_to?(:normalize)

			pos1=Geom::Point3d.new(pt1)
			pos2=Geom::Point3d.new(pt2)
			vector=Geom::Vector3d.new(vec)
			chord=pos2-pos1
			mid_chord=chord
			mid_chord.length=chord.length/2
			mid=pos1+mid_chord
			
			normal_vector=chord*vector
			depth_vector=normal_vector*chord
			depth_vector.length=depth_vector.dot(vector)/depth_vector.length
			pos3=mid+depth_vector
			
			add_arc_3point(pos1,pos3,pos2)

		end
	end
	
	module Sort
		#返回给定边线的收尾相连的链条组合，三岔即断开
		def self.edges(edge_list)
			backup_list = edge_list.clone
			list_series = []
			while not edge_list.empty? do
				sorted_list = []
				sorted_list << edge_list.shift
				vertex_0 = sorted_list[0].start
				vertex_1 = sorted_list[0].end
				while true do
					other_edges = vertex_1.edges & edge_list
					break unless other_edges.length == 1
					break if (vertex_1.edges & backup_list).length > 2 #三岔检验
					needed_edge = other_edges[0]
					sorted_list.push(needed_edge)
					vertex_1 = needed_edge.other_vertex(vertex_1)
					edge_list.delete(needed_edge)
				end
				while true do
					other_edges = vertex_0.edges & edge_list
					break unless other_edges.length == 1
					break if (vertex_0.edges & backup_list).length > 2 #三岔检验
					needed_edge = other_edges[0]
					sorted_list.unshift(needed_edge)
					vertex_0 = needed_edge.other_vertex(vertex_0)
					edge_list.delete(needed_edge)
				end
				list_series << sorted_list
			end
			return list_series
		end
	end
	
	module Surface
		#返回原点坐标和半径
		def self.triangleOR(pos)
			x1=pos[0][0]
			y1=pos[0][1]
			x2=pos[1][0]
			y2=pos[1][1]
			x3=pos[2][0]
			y3=pos[2][1]
			x0=((y2-y1)*(y3*y3-y1*y1+x3*x3-x1*x1)-(y3-y1)*(y2*y2-y1*y1+x2*x2-x1*x1))/(2.0*((x3-x1)*(y2-y1)-(x2-x1)*(y3-y1)))
			y0=((x2-x1)*(x3*x3-x1*x1+y3*y3-y1*y1)-(x3-x1)*(x2*x2-x1*x1+y2*y2-y1*y1))/(2.0*((y3-y1)*(x2-x1)-(y2-y1)*(x3-x1)))
			r=(x1-x0)*(x1-x0+(y1-y0)*(y1-y0))
			return [[x0,y0],r]
		end
		#输入点坐标数组，返回Geom::PolygonMesh
		def self.delaunay(pts)
			nil
		end
	end
	
end















