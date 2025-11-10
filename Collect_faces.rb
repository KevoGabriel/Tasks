# Método auxiliar para coletar faces de forma recursiva
def collect_faces(entities)
  faces = []

  entities.each do |e|
    case e
    when Sketchup::Face
      faces << e
    when Sketchup::Group, Sketchup::ComponentInstance
      faces.concat(collect_faces(e.definition.entities))
    end
  end

  faces
end