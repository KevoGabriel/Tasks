module CreateClonebBox
  def create_clone_from_bbox
    model = Sketchup.active_model
    selection = model.selection
    model.start_operation("Clone Retangular (Bounding Box)", true)

    begin
      if selection.empty?
        UI.messagebox("Por favor, selecione um componente ou grupo para gerar o clone.")
        return
      end

      instance = selection.first

      unless instance.is_a?(Sketchup::Group) || instance.is_a?(Sketchup::ComponentInstance)
        UI.messagebox("Selecione um grupo ou componente.")
        return
      end

      # Pega a bounding box global (já transformada)
      bbox = instance.bounds

      # 8 cantos da caixa
      corners = (0..7).map { |i| bbox.corner(i) }

      # Define o retângulo da base da bounding box
      base_corners = [
        corners[0], # inferior-frente-esquerda
        corners[1], # inferior-frente-direita
        corners[5], # inferior-trás-direita
        corners[4]  # inferior-trás-esquerda
      ]

      # Cria grupo para o clone
      entities = model.active_entities
      clone_group = entities.add_group

      # Cria a face do retângulo
      face = clone_group.entities.add_face(base_corners)
      face.reverse! if face.normal.z < 0

      # Garante que é plano e move 1mm pra cima pra evitar z-fighting
      clone_group.transform!(Geom::Transformation.translation([0, 0, 1.mm]))

      # Converte o grupo em componente (sem mover nada)
      component_instance = clone_group.to_component

      # Nomeia o componente baseado no original
      base_name = "Clone_Retangular_#{instance.definition.name rescue 'SemNome'}"
      component_instance.definition.name = base_name

      UI.messagebox("Clone retangular criado e convertido em componente com sucesso!")

    rescue => e
      UI.messagebox("Erro ao criar clone: #{e.message}")
      puts e.backtrace.join("\n")
    ensure
      model.commit_operation
    end
  end
end
