# Plugin para SketchUp - Copiar componentes ao longo de curva

require 'sketchup.rb'

module RipadoCurva
  
  # Classe principal do plugin
  class ArrayNaCurva
    
    def initialize
      @model = Sketchup.active_model
      @selection = @model.selection
    end
    
    # Método principal para executar o array
    def executar
      # Validar seleção
      unless validar_selecao
        return
      end
      
      # Separar componente e curva da seleção
      componente = nil
      curva = []
      
      @selection.each do |entidade|
        if entidade.is_a?(Sketchup::ComponentInstance) || entidade.is_a?(Sketchup::Group)
          componente = entidade
        elsif entidade.is_a?(Sketchup::Edge)
          curva << entidade
        elsif entidade.is_a?(Sketchup::Curve)
          curva = entidade.edges.to_a
        end
      end
      
      # Se não encontrou curva nas edges, tentar construir da seleção
      if curva.empty?
        curva = obter_edges_conectadas(@selection.grep(Sketchup::Edge))
      end
      
      # Solicitar quantidade de cópias
      prompts = ["Número de cópias:", "Espaçamento (deixe 0 para auto):"]
      defaults = ["10", "0"]
      input = UI.inputbox(prompts, defaults, "Configurar Array na Curva")
      
      return unless input
      
      num_copias = input[0].to_i
      espacamento = input[1].to_f
      
      # Criar as cópias
      criar_array_na_curva(componente, curva, num_copias, espacamento)
    end
    
    private
    
    # Validar se a seleção contém o necessário
    def validar_selecao
      if @selection.empty?
        UI.messagebox("Selecione um componente/grupo e uma linha ou curva.")
        return false
      end
      
      tem_componente = @selection.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
      tem_curva = @selection.any? { |e| e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Curve) }
      
      unless tem_componente && tem_curva
        UI.messagebox("Você precisa selecionar:\n- Um componente ou grupo\n- Uma ou mais linhas/curvas")
        return false
      end
      
      true
    end
    
    # Obter edges conectadas em sequência
    def obter_edges_conectadas(edges)
      return [] if edges.empty?
      
      ordenadas = [edges.first]
      edges_restantes = edges[1..-1]
      
      while !edges_restantes.empty?
        ultimo_ponto = ordenadas.last.end.position
        
        proxima = edges_restantes.find { |e| 
          e.start.position == ultimo_ponto || e.end.position == ultimo_ponto 
        }
        
        break unless proxima
        
        ordenadas << proxima
        edges_restantes.delete(proxima)
      end
      
      ordenadas
    end
    
    # Criar array de componentes ao longo da curva
    def criar_array_na_curva(componente, edges, num_copias, espacamento)
      # Calcular comprimento total da curva
      comprimento_total = 0
      edges.each { |edge| comprimento_total += edge.length }
      
      # Calcular espaçamento se for automático
      if espacamento == 0
        espacamento = comprimento_total / (num_copias - 1)
      end
      
      # Iniciar operação (para poder desfazer tudo de uma vez)
      @model.start_operation('Array na Curva', true)
      
      begin
        distancia_atual = 0
        
        (num_copias - 1).times do |i|
          distancia_atual += espacamento
          
          # Encontrar ponto e direção na curva
          ponto, direcao = encontrar_ponto_na_curva(edges, distancia_atual, comprimento_total)
          
          next unless ponto && direcao
          
          # Criar cópia do componente
          nova_instancia = componente.copy
          
          # Calcular transformação
          transformacao = calcular_transformacao(componente, ponto, direcao)
          
          # Aplicar transformação
          nova_instancia.transform! transformacao
          
          # Adicionar ao modelo
          @model.active_entities.add_instance(nova_instancia.definition, nova_instancia.transformation)
        end
        
        @model.commit_operation
        UI.messagebox("#{num_copias - 1} cópias criadas com sucesso!")
        
      rescue => erro
        @model.abort_operation
        UI.messagebox("Erro ao criar array: #{erro.message}")
      end
    end
    
    # Encontrar ponto específico ao longo da curva
    def encontrar_ponto_na_curva(edges, distancia_alvo, comprimento_total)
      # Se a distância alvo exceder o comprimento, usar o final
      distancia_alvo = comprimento_total if distancia_alvo > comprimento_total
      
      distancia_percorrida = 0
      
      edges.each do |edge|
        comprimento_edge = edge.length
        
        if distancia_percorrida + comprimento_edge >= distancia_alvo
          # O ponto está nesta edge
          proporcao = (distancia_alvo - distancia_percorrida) / comprimento_edge
          
          inicio = edge.start.position
          fim = edge.end.position
          
          # Interpolar ponto
          ponto = Geom::Point3d.new(
            inicio.x + (fim.x - inicio.x) * proporcao,
            inicio.y + (fim.y - inicio.y) * proporcao,
            inicio.z + (fim.z - inicio.z) * proporcao
          )
          
          # Calcular direção (tangente)
          direcao = edge.line[1]
          
          return [ponto, direcao]
        end
        
        distancia_percorrida += comprimento_edge
      end
      
      # Retornar o último ponto se não encontrou
      ultima_edge = edges.last
      [ultima_edge.end.position, ultima_edge.line[1]]
    end
    
    # Calcular transformação para posicionar e orientar o componente
    def calcular_transformacao(componente_original, ponto_alvo, direcao)
      # Obter posição original
      pos_original = componente_original.transformation.origin
      
      # Criar vetor de translação
      translacao = Geom::Transformation.translation(ponto_alvo - pos_original)
      
      # Normalizar direção
      direcao_normalizada = direcao.normalize
      
      # Criar rotação para alinhar com a direção da curva
      # Assumindo que queremos alinhar o eixo X do componente com a curva
      eixo_original = Geom::Vector3d.new(1, 0, 0)
      
      # Calcular ângulo e eixo de rotação
      angulo = eixo_original.angle_between(direcao_normalizada)
      eixo_rotacao = eixo_original.cross(direcao_normalizada)
      
      if eixo_rotacao.length > 0.001
        rotacao = Geom::Transformation.rotation(ponto_alvo, eixo_rotacao, angulo)
        return rotacao * translacao
      else
        return translacao
      end
    end
    
  end
  
  # Adicionar item ao menu
  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins')
    menu.add_item('Ripado em Curva') {
      array = ArrayNaCurva.new
      array.executar
    }
    file_loaded(__FILE__)
  end
  
end