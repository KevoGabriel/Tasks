def create_clone
  model = Sketchup.active_model
  model.start_operation("Configuração de Componentes para Corte", true)

  begin
    entities = model.active_entities
    definitions = model.definitions

    if selection.empty?
      UI.messagebox("Por favor, selecione um componente ou grupo para gerar o clone.")
      return
    end

