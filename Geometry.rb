module Geometry
  def create_geometry
    model = Sketchup.active_model
    model.start_operation('Configuração de Componentes para Corte', true)

    begin
      entities = model.entities

      # Cria um grupo temporário para a conversão
      grupo_temp_parede = entities.add_group

      # Converte o grupo temporário em uma Instância de Componente
      wall_instance = grupo_temp_parede.to_component

      # Obtém a Definição e suas Entidades (aqui é onde a geometria reside)
      wall_definition = wall_instance.definition
      wall_entities = wall_definition.entities
      wall_definition.name = 'parede' # Nome essencial para a função de corte

      # Adiciona a geometria à Definição do Componente
      parede_face = wall_entities.add_face([0, 0, 0], [10, 0, 0], [10, 100, 0], [0, 100, 0])
      parede_face.pushpull(-50) # Usando 50 como espessura

      # Posição final da Parede
      wall_instance.transform!(Geom::Transformation.new([0, 0, 0]))

      # Cria um grupo temporário para a conversão
      grupo_temp_caixa = entities.add_group

      # Converte o grupo temporário em uma Instância de Componente
      box_instance = grupo_temp_caixa.to_component

      # Obtém a Definição e suas Entidades
      box_definition = box_instance.definition
      box_entities = box_definition.entities
      box_definition.name = 'caixa' # Nome essencial para a função de corte

      # Adiciona a geometria à Definição do Componente
      caixa_face = box_entities.add_face([0, 0, 0], [10, 0, 0], [10, 10, 0], [0, 10, 0])
      caixa_face.pushpull(-10) # 5 metros de profundidade para garantir que atravesse

      # Posição final da Caixa (para que intercepte a Parede)
      # Move para (5m, -2.5m, 20m) para centralizar na Parede
      posicao_x = 10 # Centraliza no eixo X da parede (100m)
      posicao_y = 35 # Posiciona o cortador no meio da espessura da parede (50m)
      posicao_z = 17 # Eleva do chão

      transCaixa = Geom::Transformation.new([posicao_x, posicao_y, posicao_z])
      box_instance.transform!(transCaixa)

      model.commit_operation
      'Geometrias de Componente criadas com sucesso!'
    rescue StandardError => e
      model.abort_operation
      puts "Erro: #{e.message}"
      puts e.backtrace.join("\n")
      "Erro: #{e.message}"
    end
  end
end
