def create_clone
  model = Sketchup.active_model
  selection = model.selection
  model.start_operation("Configuração de Componentes para Corte", true)

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

    # Busca todas as faces dentro do componente, incluindo subníveis
    faces = collect_faces(instance.definition.entities)

    if faces.empty?
      UI.messagebox("O componente selecionado (ou seus subcomponentes) não possuem faces.")
      return
    end

    # Encontra a maior face pelo método de área
    largest_face = faces.max_by(&:area)
    points = largest_face.outer_loop.vertices.map(&:position)

    # Cria um grupo com a nova face
    clone_group = model.active_entities.add_group
    new_face = clone_group.entities.add_face(points)

    # Ajusta orientação se necessário
    new_face.reverse! if new_face.normal.samedirection?(largest_face.normal.reverse)

    # Aplica a mesma transformação do componente original
    tr = instance.transformation
    clone_group.transform!(tr)

    # Desloca levemente para evitar sobreposição
    begin
      normal = Geom::Vector3d.new(largest_face.normal)
      normal.length = 1.mm
      clone_group.transform!(Geom::Transformation.translation(normal))
    rescue => e
      puts "Aviso: não foi possível deslocar o clone (#{e.message})"
    end

    UI.messagebox("Clone da maior face criado com sucesso!")

  rescue => e
    UI.messagebox("Erro ao criar o clone: #{e.message}")
  ensure
    model.commit_operation
  end
end

