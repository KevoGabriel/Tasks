def drill_wall(nome_parede, nome_cortador)
  model = Sketchup.active_model
  model.start_operation('Clonar e Cortar Parede', true)

  begin
    # Localiza os componentes pelo nome
    parede  = model.entities.grep(Sketchup::ComponentInstance)
                   .find { |c| c.definition.name == nome_parede }

    cortador = model.entities.grep(Sketchup::ComponentInstance)
                     .find { |c| c.definition.name == nome_cortador }

    unless parede && cortador
      model.abort_operation
      return "Parede ou cortador não encontrados."
    end

    # Cria cortador temporário baseado no bounding box (ponto-chave)
    bbox = cortador.bounds
    corners = (0..7).map { |i| bbox.corner(i) }
    base_corners = [corners[0], corners[1], corners[5], corners[4]]

    temp_group = model.active_entities.add_group
    face = temp_group.entities.add_face(base_corners)
    face.reverse! if face.normal.z < 0

    # Necessita melhorar: se o cortador não estiver encostando na parede, o offset deveria ser variável
    temp_group.transform!(Geom::Transformation.translation([0, 0, 1.mm]))

    # Configurações da parede
    entities_parede = parede.definition.entities
    trans_parede = parede.transformation

    bounds_parede = parede.bounds
    espessura = [
      bounds_parede.width,
      bounds_parede.height,
      bounds_parede.depth
    ].min

    faces_antes = entities_parede.grep(Sketchup::Face)

    # Interseção entre o cortador temporário e a parede (ponto-chave da operação)
    model.entities.intersect_with(
      true,
      Geom::Transformation.new,
      entities_parede,
      trans_parede,
      true,
      temp_group
    )

    # PushPull apenas nas faces novas criadas pela interseção
    faces_depois = entities_parede.grep(Sketchup::Face)
    novas_faces = faces_depois - faces_antes

    novas_faces.each do |face|
      begin
        face.pushpull(-espessura)
      rescue => e
        puts "Erro pushpull: #{e.message}"
      end
    end

    # Remove o cortador temporário
    temp_group.erase! if temp_group.valid?

    model.commit_operation
    "Recorte concluído!"

  rescue => e
    model.abort_operation
    "Erro: #{e.message}"
  end
end
