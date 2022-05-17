# Contratos inteligentes para protocolo Rarible

Consiste em:

* Exchange v2: responsável por vendas, leilões etc..
* Tokens: para armazenar informações sobre NFTs
* Especificações para royalties on-chain suportadas pela Rarible

Veja mais informações sobre Rarible Protocol em [docs.rarible.org](https://docs.rarible.org).

Além disso, você pode encontrar instâncias implantadas do Rarible Smart Contracts na Mainnet, Testnet e Development em [Contract Addresses](https://docs.rarible.org/reference/contract-addresses/) página.

## Compilar, testar, implantar

```shell
yarn
yarn bootstrap
```

então use truffle para compilar, teste: cd no diretório e então

```shell
truffle test --compile-all
```

## Visão geral do protocolo

O protocolo Rarible é uma combinação de contratos inteligentes para troca de tokens, tokens próprios, APIs para criação de pedidos, descoberta, padrões usados ​​em contratos inteligentes.

O protocolo é direcionado principalmente para NFTs, mas não se limita apenas a NFTs. Qualquer ativo na blockchain EVM pode ser negociado na Rarible.

Os contratos inteligentes são construídos de forma a serem atualizados, os pedidos têm informações de versão, para que novos campos possam ser adicionados, se necessário, no futuro.

## Visão geral do processo de negociação

Os usuários devem seguir estas etapas para negociar com sucesso no Rarible:

* Aprovar downloads de seus ativos para contratos de câmbio (por exemplo, aprovarForAll para ERC-721, aprovar para ERC-20) — quantidade de dinheiro necessária para o comércio é preço + taxa em cima disso. Saiba mais em contratos de câmbio [README](https://github.com/rarible/protocol-contracts/tree/master/exchange-v2).
* Assine o pedido de negociação através da carteira preferida (o pedido é como uma declaração "Gostaria de vender meu precioso gatinho criptográfico por10 ETH").
* Salve este pedido e assinatura no banco de dados usando a API do protocolo Rarible (no futuro, o armazenamento de pedidos na cadeia também será suportado).

Se o usuário quiser cancelar o pedido, ele deve chamar a função de cancelamento do contrato inteligente do Exchange.

Os usuários que desejam comprar algo no Rarible devem fazer o seguinte:

* Find an asset they like with an open order.
* Aprovar transferências da mesma forma (se não comprar usando Ether).
* Faça o pedido na outra direção (declaração como "Eu gostaria de comprar um precioso gatinho de criptografia para 10 ETH").
* Chame Exchange.matchOrders com dois pedidos e assinatura do primeiro pedido.

## Sugestões

Você é bem vindo para [suggest features](https://github.com/rarible/protocol/discussions) 
e [report bugs found](https://github.com/rarible/protocol/issues)!

## Contribuindo

A base de código é mantida usando o "fluxo de trabalho do contribuidor", onde todos, sem exceção, contribuem com propostas de patch usando "requisições pull" (PRs). Isso facilita a contribuição social, testes fáceis e revisão por pares.

Veja mais informações em [CONTRIBUTING.md](https://github.com/rarible/protocol/blob/main/CONTRIBUTING.md).

## Licença

Contratos inteligentes para o protocolo Rarible estão disponíveis sob o [MIT License](LICENSE.md).
