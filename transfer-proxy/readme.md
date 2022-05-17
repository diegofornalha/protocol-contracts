## Contratos inteligentes de troca de protocolo raro

### Arquitetura

Contratos inteligentes de troca rara são construídos usando a biblioteca de contratos inteligentes atualizável do openzeppelin. Assim, o código do contrato inteligente pode ser atualizado para oferecer suporte a novos recursos, corrigir bugs etc.

Os contratos inteligentes são fortemente testados, os testes são fornecidos na pasta de teste.

A funcionalidade é dividida em partes (cada uma responsável pela parte do algoritmo).

Essencialmente, o ExchangeV2 é um contrato inteligente para troca descentralizada de quaisquer ativos apresentados no blockchain Ethereum (ou compatível com EVM).

### Algoritmos

A principal função no Exchange é matchOrders. Leva duas ordens (esquerda e direita), tenta combiná-las e depois preenche se houver uma correspondência.

Logicamente, todo o processo pode ser dividido em etapas:

- validação do pedido (verifique se os parâmetros do pedido são válidos e o chamador está autorizado a executar o pedido)
- cálculo de ativos (verifique se os ativos da ordem esquerda e direita correspondem, extraia ativos correspondentes)
- cálculo de preenchimento (descobrir quais valores exatos devem ser preenchidos. Os pedidos podem ser correspondidos parcialmente se um dos lados não quiser preencher totalmente o outro pedido)
- execução de pedidos (executar transferências, salvar o preenchimento dos pedidos, se necessário)

#### Modelo de domínio

**Pedido**:

- **fabricante**: endereço
- **criar ativo**: ativo
- **taker**: endereço (pode ser zero, então qualquer um pode preencher o pedido)
- **takeAsset**: Ativo
- **sal**: uint (número aleatório)
- **start**: uint (antes desta data o pedido não pode ser preenchido)
- **end**: uint (após esta data o pedido não pode ser preenchido)
- **dataType**: bytes4 (tipo de tipo de dados, geralmente hash de alguma string, por exemplo: "v1", "v2")
- **dados**: bytes (dados genéricos, podem ser qualquer coisa, parte extensível do pedido)

**De ativos**:
- **assetType**: AssetType (define o tipo de ativo - ETH, token ERC20 específico, NFT ERC721 específico etc.)
- **quantidade**: uint

**Tipo de ativo**:

- **tp**: bytes4 (tipo de tipo de ativo: ETH, ERC20, ERC721 etc.)
- **dados**: bytes (dados genéricos, descreve o tipo de ativo, por exemplo: endereço do token para ERC20, token + tokenId para ERC721)

#### Validação do pedido

- verificar a data de início/término dos pedidos
- verifique se o tomador do pedido está em branco ou taker = order.taker
- verificar se a ordem está assinada pelo seu emitente ou o emitente da ordem está executando a transação
- se o fabricante do pedido for um contrato, a verificação ERC-1271 será realizada

TODO: atualmente, apenas pedidos off-chain são suportados, esta parte do contrato inteligente pode ser facilmente atualizada para oferecer suporte a livros de pedidos on-chain.

#### Correspondência de ativos

O objetivo disso é validar se **criar ativo** do pedido **esquerdo** corresponde a **obter ativo** do pedido **direito** e vice-versa.
Novos tipos de ativos podem ser adicionados sem atualização de contrato inteligente. Isso é feito usando IAssetMatcher personalizado.

Há possíveis melhorias no protocolo usando esses correspondentes personalizados:

- suporte para ativos paramétricos. Por exemplo, o usuário pode colocar ordem para trocar 10ETH para qualquer NFT de coleção popular.
- suporte para pacotes NFT

#### Execução da ordem

A execução da ordem é feita pelo TransferManager. Existem 2 variantes:

- SimpleTransferManager (simplesmente transfere ativos de maker para taker e vice-versa)
- RaribleTransferManager (versão sofisticada, leva em conta comissões de protocolo, royalties etc)

TODO: Existem planos para estender o RaribleTransferManager para oferecer suporte a mais esquemas de royalties e adicionar novos recursos, como taxas personalizadas, vários beneficiários de pedidos.

Essa parte do algoritmo pode ser estendida com ITransferExecutor personalizado. No futuro, novos executores serão adicionados para suportar novos tipos de ativos, por exemplo, executores para manipulação de pacotes configuráveis ​​podem ser adicionados.

TODO: possíveis melhorias:

- pacotes de suporte
- suporte caixas aleatórias

#### Honorários

RaribleTransferManager suporta estes tipos de taxas:
- taxas de protocolo (são tomadas de ambos os lados do acordo)
- taxas de origem (a taxa de origem e origem é definida para cada pedido. Pode ser diferente para dois pedidos envolvidos)
- royalties (os autores da obra receberão parte de cada venda)

##### Cálculo de taxas, lado da taxa

Para receber uma taxa, precisamos calcular que lado do negócio pode ser usado como dinheiro.
Existe um algoritmo simples para fazer isso:
- se o ETH for de qualquer lado do negócio, é usado
- se não, então se o ERC-20 estiver no acordo, ele é usado
- se não, então se ERC-1155 estiver no negócio, é usado
- caso contrário, a taxa não é cobrada (por exemplo, dois ERC-721 estão envolvidos no negócio)Quando estabelecemos que parte do negócio pode ser tratada como dinheiro, podemos estabelecer que
- comprador é o lado do negócio que possui dinheiro
- o vendedor é o outro lado do negócio

Em seguida, o valor total do ativo (lado do dinheiro) deve ser calculado
- taxa de protocolo é adicionada ao valor preenchido
- a taxa de origem do pedido do comprador também é adicionada

Se o comprador estiver usando o token ERC-20 para pagamento, ele deverá aprovar pelo menos essa quantidade calculada de tokens.

Se o comprador estiver usando ETH, ele deverá enviar essa quantidade calculada de ETH com o tx.
