module DrillWall
  def drill_wall(nome_parede, nome_cortador = nil)
    model = Sketchup.active_model

    # Se não passar o nome do cortador, ele será criado agora
    unless nome_cortador
      nome_cortador = create_clone_from_bbox
      return "Erro ao criar clone." unless nome_cortador
    end

    model.start_operation("Cortar Parede", true)

    begin
      parede = model.entities.grep(Sketchup::ComponentInstance).find { |c| c.definition.name == nome_parede }
      cortador = model.entities.grep(Sketchup::ComponentInstance).find { |c| c.definition.name == nome_cortador }

      unless parede && cortador
        model.abort_operation
        return "Componentes não encontrados."
      end

      entities_parede = parede.definition.entities
      trans_parede    = parede.transformation
      trans_cortador  = cortador.transformation

      # === Calcula a espessura da parede ===
      bounds_parede = parede.bounds
      dimensoes_parede = [bounds_parede.width, bounds_parede.height, bounds_parede.depth]
      espessura_parede = dimensoes_parede.min
      puts "Espessura da parede: #{espessura_parede.to_l}"

      # === Salva faces antes da interseção ===
      faces_antes = entities_parede.grep(Sketchup::Face)

      # === Instância temporária do cortador ===
      temp_instance = model.entities.add_instance(cortador.definition, trans_cortador)

      # === Interseção ===
      model.entities.intersect_with(
        true,
        Geom::Transformation.new,
        entities_parede,
        trans_parede,
        true,
        temp_instance
      )

      # === Coleta as novas faces criadas ===
      faces_depois = entities_parede.grep(Sketchup::Face)
      faces_novas = faces_depois - faces_antes
      puts "Novas faces criadas: #{faces_novas.size}"

      # === PushPull automático ===
      if faces_novas.any?
        faces_novas.each do |face|
          distancia = -espessura_parede
          begin
            face.pushpull(distancia)
          rescue => e
            puts "Erro ao aplicar pushpull em #{face}: #{e.message}"
          end
        end
      end

      # === Limpeza ===
      temp_instance.erase!
      model.commit_operation

      return "Recorte concluído!"

    rescue => e
      model.abort_operation
      return "Erro: #{e.message}"
    end
  end
end