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
- correspondência de ativos (verifique se os ativos da ordem esquerda e direita correspondem, extraia ativos correspondentes)
- cálculo de preenchimento (descobrir quais valores exatos devem ser preenchidos. Os pedidos podem ser correspondidos parcialmente se um dos lados não quiser preencher totalmente o outro pedido)
- execução de pedidos (executar transferências, salvar o preenchimento dos pedidos, se necessário)

#### Modelo de domínio

**Pedido**:

- fabricante de `endereço`
- `Asset` leftAsset (consulte [LibAsset](../asset/contracts/LibAsset.md))
- tomador `address` (pode ser endereço zero)
- `Asset` rightAsset (consulte [LibAsset](../asset/contracts/LibAsset.md))
- `uint` salt - número aleatório para distinguir diferentes ordens do fabricante (se salt = 0, então a transação deve ser executada pelo order.maker. então o preenchimento do pedido não é salvo)
- `uint` start - O pedido não pode ser correspondido antes desta data (opcional)
- `uint` end - O pedido não pode ser correspondido após esta data (opcional)
- `bytes4` dataType - tipo de dados, geralmente hash de alguma string, por exemplo: "v1", "v2" (veja mais [aqui](./contracts/LibOrderData.md))
- dados `bytes` - dados genéricos, podem ser qualquer coisa, parte extensível do pedido (veja mais [aqui](./contracts/LibOrderData.md))

#### Execução da ordem

Quando o usuário assina o pedido, ele afirma o seguinte:

Eu gostaria de trocar meu ativo (make), até fazer valor de ativo, em troca gostaria de pegar ativo, não mais que tirar valor. As ordens podem ser preenchidas parcialmente, mas neste caso a taxa de câmbio deve ser a mesma ou deve ser mais lucrativa para mim.

Isso significa:
- o usuário pode dar menos que make.value
- o usuário não pode receber mais do que take.value (o pedido é preenchido quando o usuário recebe o que deseja receber)

O preenchimento do pedido é salvo dentro do contrato inteligente e está relacionado à parte de recebimento do pedido. Fill é armazenado dentro do mapeamento, onde a chave é calculada usando estes campos: maker, make asset type, take asset type, salt. Ou seja, o preenchimento dos pedidos que diferem apenas na taxa de câmbio são armazenados no mesmo slot de mapeamento.

Além disso, os pedidos que estão totalmente preenchidos podem ser estendidos: os usuários podem assinar novos pedidos usando o mesmo sal (eles podem aumentar make.value e take.value, por exemplo).

Prioridade da taxa de pedido: se as taxas de câmbio forem diferentes, mas os pedidos puderem ser preenchidos (por exemplo, o pedido esquerdo é 10X -> 100Y, mas o direito é 100Y -> 5X), então o pedido esquerdo determina a taxa de câmbio.

Erros de arredondamento: para calcular os valores de preenchimento, são utilizadas operações matemáticas. Quando o arredondamento é realizado e o erro é superior a 0,1%, o erro de arredondamento será lançado e a ordem não poderá ser executada.

#### Validação do pedido

Além disso, os pedidos que estão totalmente preenchidos podem ser pedidos estendidos: os mesmos usuários podem aumentar.

Prioridade de taxa de pedido: se as taxas de câmbio são diferentes, mas os pedidos podem ser preenchidos esquerdos (exemplo, o pedido é 10X -> 100Y, mas o direito é 100Y -> 5X), então o pedido determina a taxa de câmbio.

Erros de arredondamento: para valores utilizados, operações matemáticas. Quando o arredondamento for superior a 0,1%, o erro será lançado e a ordem de arredondamento não poderá ser entregue o erro realizado.

#### Validação do pedido

O objetivo disso é validar se **criar ativo** do pedido **esquerdo** corresponde a **obter ativo** do pedido **direito** e vice-versa.
Novos tipos de ativos podem ser adicionados sem atualização de contrato inteligente. Isso é feito usando IAssetMatcher personalizado.

Há possíveis melhorias no protocolo usando esses correspondentes personalizados:

- suporte para ativos paramétricos. Por exemplo, o usuário pode colocar ordem para trocar 10ETH para qualquer NFT de coleção popular.
- suporte para pacotes NFT

#### Execução de transferências

As transferências são feitas pelo TransferManager. Existem 2 variantes:

- SimpleTransferManager (simplesmente transfere ativos de maker para taker e vice-versa)
- RaribleTransferManager (versão sofisticada, leva em conta comissões de protocolo, royalties etc)


TODO: Existem planos para estender o RaribleTransferManager para oferecer suporte a mais esquemas de royalties e adicionar novos recursos, como taxas personalizadas, vários beneficiários de pedidos.

Essa parte do algoritmo pode ser estendida com ITransferExecutor personalizado. No futuro, novos executores serão adicionados para suportar novos tipos de ativos, por exemplo, executores para manipulação de pacotes configuráveis ​​podem ser adicionados.

TODO: possíveis melhorias:

- pacotes de suporte
- suporte caixas aleatórias

#### Executando transferências ETH

Os fabricantes dos pedidos e endereços no campo de pagamentos em `order.data` podem ser contratos. Portanto, esses contratos devem ter funções de fallback pagáveis ​​para aceitar transferências ETH recebidas. Em outros casos, o tx falhará.

O mesmo se aplica ao campo de origem, receptores de royalties.

#### Honorários

RaribleTransferManager suporta estes tipos de taxas:
- taxas de protocolo (são tomadas de ambos os lados do acordo)
- taxas de origem (a taxa de origem e origem é definida para cada pedido. Pode ser diferente para dois pedidos envolvidos)
- royalties (os autores da obra receberão parte de cada venda)

Os royalties do item não podem ser superiores a 30% por motivos de segurança. Se os royalties forem superiores a 30%, a transação é revertida.

##### Cálculo de taxas, lado da taxa

Para receber uma taxa, precisamos calcular que lado do negócio pode ser usado como dinheiro.
Existe um algoritmo simples para fazer isso:
- se o ETH for de qualquer lado do negócio, é usado
- se não, então se o ERC-20 estiver no acordo, ele é usado
- se não, então se ERC-1155 estiver no negócio, é usado
- caso contrário, a taxa não é cobrada (por exemplo, dois ERC-721 estão envolvidos no negócio)
- Quando estabelecemos que parte do negócio pode ser tratada como dinheiro, podemos estabelecer que
- comprador é o lado do negócio que possui dinheiro
- o vendedor é o outro lado do negócio

Em seguida, o valor total do ativo (lado do dinheiro) deve ser calculado
- taxa de protocolo é adicionada ao valor preenchido
- a taxa de origem do pedido do comprador também é adicionada

Se o comprador estiver usando o token ERC-20 para pagamento, ele deverá aprovar pelo menos essa quantidade calculada de tokens.

Se o comprador estiver usando ETH, ele deverá enviar essa quantidade calculada de ETH com o tx.

##### Cancelando o pedido

A função cancelar pode ser usada para cancelar o pedido. Esses pedidos não serão correspondidos e um erro será lançado. Esta função é usada pelo fabricante de pedidos para marcar pedidos não preenchíveis. Esta função pode ser invocada apenas pelo fabricante do pedido.

TODO: existe a possibilidade de alterar a autorização para a função de cancelamento - adicionar autorização por assinatura. Possivelmente, isso será adicionado no futuro.

##### Eventos de contrato

O contrato ExchangeV2 emite estes eventos:
- Match (quando os pedidos são combinados)
- Cancelar (quando o usuário cancela o pedido)

TODO: atualmente, não há campos indexados em eventos, pois o protocolo rarible utiliza indexação interna. Possivelmente, campos indexados serão adicionados no futuro.
