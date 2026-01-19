# =========================================================
# Configurações principais
# =========================================================
include .env

.PHONY: deploy-anvil deploy-sepolia test clean rebuild

RPC_ANVIL := $(ANVIL_RPC_URL)
RPC_SEPOLIA := $(SEPOLIA_RPC_URL)
ANVIL_PRIVATE_KEY := $(ANVIL_PRIVATE_KEY)
SEPOLIA_NAME_KEY := $(SEPOLIA_NAME_KEY)
SEPOLIA_SENDER := $(SEPOLIA_SENDER)
DEPLOYER_ADDRESS := $(DEPLOYER_ADDRESS)
DEPLOYED_ADDRESS := $(DEPLOYED_ADDRESS)

DEPLOY_SCRIPT := script/DeployFamilyVault.s.sol:DeployFamilyVault

# =========================================================
# Deploys
# =========================================================

# Deploy local usando Anvil
deploy-anvil:
	@echo "🚀 Deployando FamilyVault na rede Anvil..."
	forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(RPC_ANVIL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast

# Deploy na rede Sepolia
deploy-sepolia:
	@echo "🌐 Deployando FamilyVault na rede Sepolia..."
	forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(RPC_SEPOLIA) \
		--account $(SEPOLIA_NAME_KEY) \
		--sender $(SEPOLIA_SENDER) \
		--broadcast \
		> last_deploy.log

# Verificação do contrato na rede Sepolia
verify-factory:
ifndef DEPLOYED_ADDRESS
	$(error DEPLOYED_ADDRESS não definido. Atualize com o endereço do contrato deployado)
endif
	@echo "🔍 Verificando FamilyVaultFactory no Sepolia..."
	@forge verify-contract \
		--chain-id 11155111 \
		--verifier etherscan \
		$(DEPLOYED_ADDRESS) \
		src/contracts/FamilyVaultFactory.sol:FamilyVaultFactory 


# Deploy MockToken local usando Anvil
deploy-mocktoken:
	@echo "🚀 Deployando MockToken na rede Anvil..."
	forge script script/DeployMockToken.s.sol:DeployMockToken \
		--rpc-url $(RPC_ANVIL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast

# ================================
# Limpeza
# ================================

# Limpar build e cache
clean:
	@echo "🧹 Limpando build e cache..."
	forge clean


# Rodar testes completos
test:
	@echo "🧪 Rodando testes..."
	forge test -vvv


# Rebuild total
rebuild: clean
	forge build

# ================================
# Cobertura de testes
# ================================

# Gera relatório de cobertura ignorando bibliotecas (OpenZeppelin etc.)
coverage:
	@echo "📊 Gerando relatório de cobertura..."
	forge coverage --report lcov \
		--report-file coverage/lcov.info \
		--match-path "test/*"

# Abre cobertura no VSCode (necessita extensão Coverage Gutters)
coverage-open:
	@echo "📂 Abra o arquivo coverage/lcov.info no VSCode com Coverage Gutters"

# ================================
# Build & Tamanho do Contrato
# ================================

# Compilar e ver tamanho do runtime bytecode
build-sizes:
	@echo "📐 Verificando tamanho dos contratos..."
	forge build --sizes

# Compilar tudo
build:
	@echo "🔨 Compilando projeto..."
	forge build

# ================================
# Atalhos
# ================================

# Rodar tudo: limpeza, build, testes e deploy
all: clean build test deploy-anvil