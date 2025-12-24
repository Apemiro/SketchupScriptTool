
module Geo
	# 将EsriJSON中的面数据导入SketchUp并将字段值赋值给面要素
	# 不能读取多部件，请在GIS中将多部件转至单部件
	# 创建的平面自动打组并平移到原点附近，平移参数保存在群组的EsriJSONAttribute属性中
	
	def self.importFacesFromEsriJSON(filename)
		
		#读取EsriJSON
		json_file = File.open(filename,"r")
		json_string = json_file.read()
		json = JSON.parse(json_string)
		json_file.close()
		if json["geometryType"] != "esriGeometryPolygon" then
			raise ArgumentError.new("Geometry type of EsriJSON is not Polygon.")
		end
		
		#创建面操作
		failure_count = 0
		Sketchup.active_model.start_operation("Import Faces From EsriJSON")
		begin
			face_generated = []
			Sketchup.active_model.entities.build{|builder|
				json["features"].each{|feature|
					loops = feature["geometry"]["rings"]
					if loops.respond_to?(:[]) then
						outer_loop = (loops[0][0..-2]).map{|point|point.map(&:m)}
						inner_loops = loops[1..-1].map{|loop|loop[0..-2].map{|point|point.map(&:m)}}
						face = builder.add_face(outer_loop, holes: inner_loops)
						feature["attributes"].each{|key, value|
							face.set_attribute("EsriJSONAttribute",key,value)
						}
						face_generated << face
					else
						failure_count += 1
					end
				}
			}
			Sketchup.active_model.entities.weld(face_generated.map{|f|f.edges}.flatten.uniq) if Sketchup.active_model.entities.respond_to?(:weld)
			group = Sketchup.active_model.entities.add_group(face_generated.map(&:all_connected).flatten.uniq)
			offset = group.bounds.min
			trans = Geom::Transformation.translation(offset)
			group.transform!(trans.inverse)
			group.set_attribute("EsriJSONAttribute","Offset_X",offset[0])
			group.set_attribute("EsriJSONAttribute","Offset_Y",offset[1])
		rescue
			Sketchup.active_model.abort_operation()
			raise RuntimeError.new("FacesDrawingError.")
		end
		Sketchup.active_model.commit_operation()
		return failure_count
	end
end




#测试代码

# Geo.importFacesFromEsriJSON("F:\\Apiglio\\WorkPath\\tmp\\lmc_esrijson.json")
# load "F:\\Apiglio\\SketchupScriptTool\\Sel.rb"
# load "F:\\Apiglio\\SketchupScriptTool\\Cam.rb"
# Cam.vw
# Sel.sels[0].attribute_dictionaries["EsriJSONAttribute"].to_h
# Sel.sels[0].loops[0].edges.each_with_index{|e,i|Sketchup.active_model.entities.add_text(i.to_s,e.bounds.center)}
# Sel.reselect{|i|i.is_a?Sketchup::Text}

# Sel.f
# Sketchup.active_model.start_operation("Pushpull by FAR")
# Sel.sels.to_a.each{|f|
	# floor_area_ratio = f.get_attribute("EsriJSONAttribute","FAR")
	# f.pushpull(-floor_area_ratio*50.m) if floor_area_ratio!=0
	# puts floor_area_ratio
# }
# Sketchup.active_model.commit_operation()



# mats = Sketchup.active_model.materials
# GB50137=[
	# {"code"=>"A","name"=>"公共管理与公共服务设施用地","color"=>0x3F00FF},
	# {"code"=>"A1","name"=>"行政办公用地","color"=>0x9F7FFF},
	# {"code"=>"A2","name"=>"文化设施用地","color"=>0x7F9FFF},
	# {"code"=>"A21","name"=>"图书展览用地","color"=>0x7F9FFF},
	# {"code"=>"A22","name"=>"文化活动用地","color"=>0x7F9FFF},
	# {"code"=>"A3","name"=>"教育科研用地","color"=>0xBF7FFF},
	# {"code"=>"A31","name"=>"高等院校用地","color"=>0xBF7FFF},
	# {"code"=>"A32","name"=>"中等专业学校用地","color"=>0xBF7FFF},
	# {"code"=>"A33","name"=>"中小学用地","color"=>0x7FFFFF},
	# {"code"=>"A34","name"=>"特殊教育用地","color"=>0xBF7FFF},
	# {"code"=>"A35","name"=>"科研用地","color"=>0xBF7FFF},
	# {"code"=>"A4","name"=>"体育用地","color"=>0x7FFF},
	# {"code"=>"A41","name"=>"体育场馆用地","color"=>0x7FFF},
	# {"code"=>"A42","name"=>"体育训练用地","color"=>0x7FFF},
	# {"code"=>"A5","name"=>"医疗卫生用地","color"=>0x7F7FFF},
	# {"code"=>"A51","name"=>"医院用地","color"=>0x7F7FFF},
	# {"code"=>"A52","name"=>"卫生防疫用地","color"=>0x7F7FFF},
	# {"code"=>"A53","name"=>"特殊医疗用地","color"=>0x7F7FFF},
	# {"code"=>"A59","name"=>"其他医疗卫生用地","color"=>0x7F7FFF},
	# {"code"=>"A6","name"=>"社会福利用地","color"=>0x7F66CC},
	# {"code"=>"A7","name"=>"文物古迹用地","color"=>0x33CC},
	# {"code"=>"A8","name"=>"外事用地","color"=>0x3F7F4F},
	# {"code"=>"A9","name"=>"宗教用地","color"=>0x7F66CC},
	# {"code"=>"B","name"=>"商业服务业设施用地","color"=>0x3F00FF},
	# {"code"=>"B1","name"=>"商业用地","color"=>0x3F00FF},
	# {"code"=>"B11","name"=>"零售商业用地","color"=>0x3F00FF},
	# {"code"=>"B12","name"=>"批发市场用地","color"=>0x3F00FF},
	# {"code"=>"B13","name"=>"餐饮用地","color"=>0x3F00FF},
	# {"code"=>"B14","name"=>"旅馆用地","color"=>0x3F00FF},
	# {"code"=>"B2","name"=>"商务用地","color"=>0x3F00FF},
	# {"code"=>"B21","name"=>"金融保险用地","color"=>0x3F00FF},
	# {"code"=>"B22","name"=>"艺术传媒用地","color"=>0x7F9FFF},
	# {"code"=>"B29","name"=>"其他商务用地","color"=>0x3F00FF},
	# {"code"=>"B3","name"=>"娱乐康体用地","color"=>0x7F9FFF},
	# {"code"=>"B31","name"=>"娱乐用地","color"=>0x7F9FFF},
	# {"code"=>"B32","name"=>"康体用地","color"=>0x7F9FFF},
	# {"code"=>"B4","name"=>"公用设施营业网点用地","color"=>0x7F9FFF},
	# {"code"=>"B41","name"=>"加油加气站用地","color"=>0x7F9FFF},
	# {"code"=>"B49","name"=>"其他公用设施营业网点用地","color"=>0x7F9FFF},
	# {"code"=>"B9","name"=>"其他服务设施用地","color"=>0x7F9FFF},
	# {"code"=>"E","name"=>"非建设用地","color"=>0x66CC66},
	# {"code"=>"E1","name"=>"水域","color"=>0xFFFF7F},
	# {"code"=>"E11","name"=>"自然水域","color"=>0xFFFF7F},
	# {"code"=>"E12","name"=>"水库","color"=>0xFFFF7F},
	# {"code"=>"E13","name"=>"坑塘沟渠","color"=>0xFFFF7F},
	# {"code"=>"E2","name"=>"农林用地","color"=>0xCC33},
	# {"code"=>"E9","name"=>"其他非建设用地","color"=>0x4C9999},
	# {"code"=>"G","name"=>"绿地与广场用地","color"=>0x9900},
	# {"code"=>"G1","name"=>"公园绿地","color"=>0x3FFF00},
	# {"code"=>"G2","name"=>"防护绿地","color"=>0x9900},
	# {"code"=>"G3","name"=>"广场用地","color"=>0x808080},
	# {"code"=>"H","name"=>"建设用地","color"=>0x99CC},
	# {"code"=>"H1","name"=>"城乡居民点建设用地","color"=>0x99CC},
	# {"code"=>"H11","name"=>"城市建设用地","color"=>0x99CC},
	# {"code"=>"H12","name"=>"镇建设用地","color"=>0x66CCCC},
	# {"code"=>"H13","name"=>"乡建设用地","color"=>0x66CCCC},
	# {"code"=>"H14","name"=>"村庄建设用地","color"=>0x66CCCC},
	# {"code"=>"H2","name"=>"区域交通设施用地","color"=>0x3300CC},
	# {"code"=>"H21","name"=>"铁路用地","color"=>0xC0C0C0},
	# {"code"=>"H22","name"=>"公路用地","color"=>0xC0C0C0},
	# {"code"=>"H23","name"=>"港口用地","color"=>0xC0C0C0},
	# {"code"=>"H24","name"=>"机场用地","color"=>0xC0C0C0},
	# {"code"=>"H25","name"=>"管道运输用地","color"=>0xC0C0C0},
	# {"code"=>"H3","name"=>"区域公共设施用地","color"=>0x997200},
	# {"code"=>"H4","name"=>"特殊用地","color"=>0x3F7F4F},
	# {"code"=>"H41","name"=>"军事用地","color"=>0x3F7F4F},
	# {"code"=>"H42","name"=>"安保用地","color"=>0x3F7F4F},
	# {"code"=>"H5","name"=>"采矿用地","color"=>0x99CC},
	# {"code"=>"H9","name"=>"其他建设用地","color"=>0x66CCCC},
	# {"code"=>"M","name"=>"工业用地","color"=>0x4C7299},
	# {"code"=>"M1","name"=>"一类工业用地","color"=>0x4C7299},
	# {"code"=>"M2","name"=>"二类工业用地","color"=>0x3F5F7F},
	# {"code"=>"M3","name"=>"三类工业用地","color"=>0x26394C},
	# {"code"=>"R","name"=>"居住用地","color"=>0xFFFF},
	# {"code"=>"R1","name"=>"一类居住用地","color"=>0x7FFFFF},
	# {"code"=>"R11","name"=>"住宅用地","color"=>0x7FFFFF},
	# {"code"=>"R12","name"=>"服务设施用地","color"=>0x7FFFFF},
	# {"code"=>"R2","name"=>"二类居住用地","color"=>0xFFFF},
	# {"code"=>"R21","name"=>"住宅用地","color"=>0xFFFF},
	# {"code"=>"R22","name"=>"服务设施用地","color"=>0xFFFF},
	# {"code"=>"R3","name"=>"三类居住用地","color"=>0x66CCCC},
	# {"code"=>"R31","name"=>"住宅用地","color"=>0x66CCCC},
	# {"code"=>"R32","name"=>"服务设施用地","color"=>0x66CCCC},
	# {"code"=>"S","name"=>"道路与交通设施用地","color"=>0x808080},
	# {"code"=>"S1","name"=>"城市道路用地","color"=>0x808080},
	# {"code"=>"S2","name"=>"城市轨道交通用地","color"=>0x808080},
	# {"code"=>"S3","name"=>"交通枢纽用地","color"=>0xC0C0C0},
	# {"code"=>"S4","name"=>"交通场站用地","color"=>0x808080},
	# {"code"=>"S41","name"=>"公共交通场站用地","color"=>0x808080},
	# {"code"=>"S42","name"=>"社会停车场用地","color"=>0x808080},
	# {"code"=>"S9","name"=>"其他交通设施用地","color"=>0x99854C},
	# {"code"=>"U","name"=>"公用设施用地","color"=>0x997200},
	# {"code"=>"U1","name"=>"供应设施用地","color"=>0x997200},
	# {"code"=>"U11","name"=>"供水用地","color"=>0x997200},
	# {"code"=>"U12","name"=>"供电用地","color"=>0x997200},
	# {"code"=>"U13","name"=>"供燃气用地","color"=>0x997200},
	# {"code"=>"U14","name"=>"供热用地","color"=>0x997200},
	# {"code"=>"U15","name"=>"通信用地","color"=>0x997200},
	# {"code"=>"U16","name"=>"广播电视用地","color"=>0x997200},
	# {"code"=>"U2","name"=>"环境设施用地","color"=>0x997200},
	# {"code"=>"U21","name"=>"排水用地","color"=>0x997200},
	# {"code"=>"U22","name"=>"环卫用地","color"=>0x997200},
	# {"code"=>"U3","name"=>"安全设施用地","color"=>0x997200},
	# {"code"=>"U31","name"=>"消防用地","color"=>0x997200},
	# {"code"=>"U32","name"=>"防洪用地","color"=>0x997200},
	# {"code"=>"U9","name"=>"其他公用设施用地","color"=>0x997200},
	# {"code"=>"W","name"=>"物流仓储用地","color"=>0xFF7F9F},
	# {"code"=>"W1","name"=>"一类物流仓储用地","color"=>0xFF7F9F},
	# {"code"=>"W2","name"=>"二类物流仓储用地","color"=>0xFF7F9F},
	# {"code"=>"W3","name"=>"三类物流仓储用地","color"=>0xFF7F9F}
# ]
# GB50137.each{|row|
	# tmp=mats.add("YD-"+row["code"]);tmp.color=row["color"];
# }

# Sel.f
# Sel.sels.each{|f|lyr=f.get_attribute("EsriJSONAttribute","layer");f.material=mats[lyr]}



