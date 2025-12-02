def drill_wall(nome_parede, nome_cortador)
  model = Sketchup.active_model
  model.start_operation('Clonar e Cortar Parede', true)

  begin
    # Localiza componentes
    parede = model.entities.grep(Sketchup::ComponentInstance).find { |c| c.definition.name == nome_parede }
    cortador_orig = model.entities.grep(Sketchup::ComponentInstance).find { |c| c.definition.name == nome_cortador }

    unless parede && cortador_orig
      model.abort_operation
      return "Parede ou cortador não encontrados."
    end

    # Cria clone retangular
    bbox = cortador_orig.bounds
    corners = (0..7).map { |i| bbox.corner(i) }

    base_corners = [corners[0], corners[1], corners[5], corners[4]]

    clone_group = model.active_entities.add_group
    face = clone_group.entities.add_face(base_corners)
    face.reverse! if face.normal.z < 0
    clone_group.transform!(Geom::Transformation.translation([0, 0, 1.mm])) # Necessito mehorar isso para o Y ser variavel caso o cortador não esteja encostando na face da parede

    cortador_clone = clone_group.to_component
    cortador_clone.definition.name = "Clone_Retangular_#{cortador_orig.definition.name rescue 'SemNome'}"

    # Configurações da parede
    entities_parede = parede.definition.entities
    trans_parede = parede.transformation
    trans_clone = cortador_clone.transformation

    bounds_parede = parede.bounds
    espessura = [bounds_parede.width, bounds_parede.height, bounds_parede.depth].min

    faces_antes = entities_parede.grep(Sketchup::Face)

    # Instância temporária para interseção
    temp = model.entities.add_instance(cortador_clone.definition, trans_clone)

    model.entities.intersect_with(
      true,
      Geom::Transformation.new,
      entities_parede,
      trans_parede,
      true,
      temp
    )

    # PushPull nas novas faces
    faces_depois = entities_parede.grep(Sketchup::Face)
    novas = faces_depois - faces_antes

    novas.each do |face|
      begin
        face.pushpull(-espessura)
      rescue => e
        puts "Erro pushpull: #{e.message}"
      end
    end

    # Limpeza
    temp.erase! if temp.valid?
    cortador_clone.erase! if cortador_clone.valid?
    # Se quiser remover o cortador original (janela), descomente a linha abaixo
    # cortador_orig.erase!

    model.commit_operation
    "Recorte concluído!"
  rescue => e
    model.abort_operation
    "Erro: #{e.message}"
  end
end