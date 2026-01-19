# GESTFINFAM - FamilyVault

## 1. Visão Geral

O **FamilyVault** é um sistema de gestão financeira familiar on-chain, projetado para permitir que grupos (famílias, núcleos ou organizações privadas) administrem fundos compartilhados de forma segura, auditável e com regras claras de governança.

O sistema permite:
- Controle de gastos por **categorias com limite mensal**;
- Delegação de poder de gasto a membros específicos;
- Definição de **allowances individuais** por categoria;
- Execução de **gastos diretos** ou via **requisições de aprovação**;
- Suporte a token nativo da rede, conforme a rede utilizada (ex.: ETH, BNB, MATIC, etc.) e múltiplos **tokens ERC20**. 

Este repositório contém **apenas o backend on-chain**, composto por contratos Solidity modulares, organizados em um padrão de `proxy + delegatecall`, sem qualquer responsabilidade de interface (UI).


---


## 2. Arquitetura Geral

O sistema é baseado em três pilares principais:


### 2.1. Proxy + Módulos
Cada família é um **proxy isolado (ERC1967)**.
A lógica é distribuída em **módulos especializados**, chamados via `delegatecall`.
O proxy `(FamilyVault)` mantém:
  - Storage centralizado;
  - Mapeamento de `function selector → módulo`.


### 2.2. Storage Centralizado
Todo o estado é definido no contrato `FamilyVaultStorage`.
Todos os módulos herdam esse storage via `FamilyVaultBase`.
Isso garante consistência de dados e upgrade seguro.


### 2.3. Factory
A criação de novas famílias é feita via `FamilyVaultFactory`.
Cada chamada cria:
- Um novo proxy;
- Com todos os módulos já registrados;
- Com o criador definido como `OWNER`.


---


## 3. Papéis (Roles)
O controle de acesso é baseado em `AccessControlEnumerableUpgradeable`.

Roles disponíveis:
- `OWNER_ROLE`
- Controle total do cofre.
- Gerencia membros, categorias, allowances, tokens e aprova requisições.

- `SPENDER_ROLE`
- Pode gastar diretamente dentro de sua allowance.
- Pode criar requisições de gasto.

- `GUARDIAN_ROLE`
- Pode pausar/despausar membros.
- Atua como papel de segurança intermediário.

**Observação:** sempre deve existir pelo menos um `OWNER` ativo.


---


## 4. Principais Conceitos

### 4.1. Categorias
Categorias representam áreas de gasto, como:
- Mercado
- Saúde
- Educação
- Lazer

Cada categoria possui:
- `monthlyLimit:` limite mensal;
- `spent:` valor já gasto no período;
- `periodStart:` início do ciclo;
- `token:` token associado (token nativo da rede ou ERC20);
- `active:` status.

O ciclo mensal é automaticamente resetado após **30 dias** ou manualmente por um `OWNER`.


### 4.2. Allowances
Allowance define **quanto um membro pode gastar** em uma categoria.
A allowance é:
- Específica por **membro + categoria + token**;
- Independente do limite da categoria.
  
O valor disponível é sempre:

`min(allowance do membro, limite restante da categoria)`


Há controle explícito para saber se uma allowance já foi definida `(allowanceSet)`.


### 4.3. Gastos Diretos
Executados por membros com `SPENDER_ROLE`.
Regras:
- Respeitam allowance do membro;
- Respeitam limite mensal da categoria;
- Transferem token nativo que depende da rede onde o contrato esta implantado (ex.: ETH, BNB, MATIC, etc) ou tokens ERC20 previamente cadastrados, diretamente do cofre.


### 4.4. Requisições de Gasto
Requisições de gasto representam um **fluxo excepcional**, utilizado quando um membro precisa realizar um gasto **fora ou acima da sua allowance individual, mas ainda dentro do limite da categoria.**

Fluxo:
- Um membro com papel SPENDER cria uma requisição de gasto (PENDING);
- Um membro com papel OWNER analisa a solicitação e pode aprovar ou negar;

Quando aprovada:
- O valor é debitado exclusivamente do limite mensal da categoria;
- Não consome nem altera a allowance do membro solicitante;
- O pagamento é executado imediatamente para o destinatário informado.

Esse mecanismo permite:
- Flexibilidade pontual sem quebrar a disciplina de allowances;
- Gastos extraordinários com controle explícito do OWNER;
- Manutenção do histórico e rastreabilidade das exceções.

- Estados possíveis:
- `PENDING`
- `APPROVED`
- `DENIED`
- `CANCELED`


### 4.5. Tokens
O sistema suporta múltiplos tokens ERC20.
Tokens precisam ser explicitamente cadastrados pelo OWNER.
Cada token possui:
- `symbol`;
- `active`.

O token nativo da rede é representado por `address(0)`.


---


## 5. Contratos Principais

### 5.1. FamilyVault (Proxy)
Contrato central que:
- Mantém o storage;
- Faz roteamento de chamadas (fallback);
- Gerencia pause/unpause global.


### 5.2. FamilyVaultFactory
Responsável por criar novas famílias.
Cada família é um `proxy ERC1967` independente.
Mantém histórico:
- Todas as famílias criadas;
- Famílias por owner.


### 5.3. FamilyVaultBase
Contrato base compartilhado por todos os módulos, contendo:
- Modifiers;
- Errors;
- Eventos globais;
- Funções internas críticas:
  - `_executeExpense`
  - `_applySpend`
  - `_resetIfNewPeriod`
  - `_transferFunds`


---


## 6. Módulos Funcionais

### 6.1. Member Module (FamilyVaultMember)
Responsável por:
- Adicionar/remover membros;
- Atualizar roles;
- Pausar/despausar membros;
- Consultar status e roles.


### 6.2. Category Module (FamilyVaultCategory)
Responsável por:
- Criar, atualizar e desativar categorias;
- Gerenciar limites mensais;
- Associar tokens;
- Consultas de categorias.


### 6.3. Allowance Module (FamilyVaultAllowance)
Responsável por:
- Definir allowance inicial;
- Ajustar allowance (+ ou -);
- Consultar allowance total e disponível;
- Verificar se allowance já foi definida.


### 6.4 Fund Module (FamilyVaultFund)
Responsável por:
- Gastos diretos;
- Depósitos e saques de token nativo da rede;
- Depósitos e saques de ERC20;
- Consulta de saldo do cofre.


### 6.5 Request Module (FamilyVaultRequest)
Responsável por:
- Criar requisições;
- Aprovar, negar ou cancelar;
- Executar gastos aprovados;
- Listagem de requisições por status.


### 6.6 Token Module (FamilyVaultToken)
Responsável por:
- Registrar tokens ERC20;
- Ativar/desativar tokens;
- Consultar tokens cadastrados.


---



## 7. Segurança
Proteção contra reentrância (`ReentrancyGuardUpgradeable`);
Controle rigoroso de roles;
Pausa global do contrato;
Pausa individual de membros;
Validação de saldo antes de transferências;
Uso de SafeERC20.


---


## 8. Limitações Conhecidas / Roadmap

Algumas funções de listagem (`getAllCategories`, `getRequestsByStatus`) estão marcadas para futura migração para **indexador off-chain**.
Não há UI neste repositório.
Estratégia de upgrade de módulos: O sistema suporta upgrade modular via redirecionamento de selectors no proxy. A definição de políticas de upgrade e governança fica a cargo da implementação e do operador do contrato.


---


## 9. Instalação e Desenvolvimento Local

Este repositório utiliza Foundry como framework principal para desenvolvimento, testes e deploy dos contratos Solidity.


### 9.1. Pré-requisitos
- Git
- Rust (necessário para Foundry)
- Foundry (forge, cast, anvil)
- Node.js (opcional, apenas se usado em ferramentas auxiliares)

Instalação do Foundry:

`curl -L https://foundry.paradigm.xyz | bash`

`foundryup`


### 9.2. Clonando o Repositório
`git clone https://github.com/chimenamantovam/gestfinfam.git`

`cd gestfinfam`


### 9.3. Variáveis de Ambiente
O projeto utiliza um arquivo `.env` para configuração de RPCs, chaves e endereços.

Exemplo de variáveis utilizadas:

`ANVIL_RPC_URL=http://127.0.0.1:8545`

`ANVIL_PRIVATE_KEY=0x...`

`SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/...`

`SEPOLIA_NAME_KEY=sepolia`

`SEPOLIA_SENDER=0x...`

`DEPLOYED_ADDRESS=0x...`

`ETHERSCAN_API_KEY=...`


### 9.4. Build e Testes
Compilar os contratos:
`make build`

Rodar todos os testes:
`make test`

Rebuild completo (limpa cache + build):
`make rebuild`

Gerar relatório de cobertura:
`make coverage`


### 9.5. Deploy Local (Anvil)
Inicie um nó local com Anvil:
`anvil`

Em outro terminal, execute o deploy:
`make deploy-anvil`

Opcionalmente, é possível deployar um token ERC20 mock para testes locais:
`make deploy-mocktoken`


### 9.6. Deploy em Testnet (Sepolia)
Para deploy na rede Sepolia:
`make deploy-sepolia`

O endereço do contrato implantado será salvo em `last_deploy.log`.


### 9.7. Verificação do Contrato (Sepolia)
Após o deploy, defina o endereço do contrato:
`export DEPLOYED_ADDRESS=0x...`

Execute a verificação:
`make verify-factory`


### 9.8. Observações Importantes
- O deploy é realizado via `FamilyVaultFactory`;
- Cada execução cria um novo proxy `FamilyVault` isolado;
- O sistema é **agnóstico à rede**, funcionando em qualquer blockchain compatível com EVM;
- Este repositório **não inclui UI ou frontend**.


---


## 10. Endereço dos contratos deployados na rede Sepolia Testnet
- **Factory Address:**  0x033f44AdF10B4F3B0898AaeBbD341Cc8E261A716
- **Implementation Address:**  0x8D4f6BF4596Ea38f85691011Dd607C3379Bb0aB1
- **Allowance Module:**  0x277912cb0384E1b1D085D8e4a8fF585412634c4f
- **Category Module:**  0x5EB2AFfaD63509b21F6fe37A76D8F77c8294deD4
- **Fund Module:**  0xe41c2f908E8a263742cB36B6B346dB673485018d
- **Member Module:**  0x4c6f55985C9DaADD5A1cE55Ce948AA6eb82FD222
- **Request Module:**  0xF7E8c9397761aa23f4E3cDe63B0e2468cf6a2B26
- **Token Module:**  0x2F89a0968CDB6aB14A4c6f4AdDFC3e3a6810C2fA


---


## 11. Licença

MIT License.