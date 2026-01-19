//SPDX-License-Identifier:MIT
pragma solidity ^0.8.27;

import {FamilyVaultBase} from "../base/FamilyVaultBase.sol";
import {FamilyVaultTypes} from "../types/FamilyVaultTypes.sol";

contract FamilyVaultRequest is FamilyVaultBase {
    /** @notice Emite quando uma requisição de gasto é criada */
    /* string note será armazenado off-chain*/
    event RequestCreated(
        uint256 indexed requestId,
        address indexed by,
        uint64 indexed categoryId,
        uint128 amount,
        string note
    );
    /** @notice Emite quando uma requisição é aprovada */
    event RequestApproved(uint256 indexed requestId, address approver);
    /** @notice Emite quando uma requisição é negada */
    event RequestDenied(
        uint256 indexed requestId,
        address approver,
        string reason
    );
    /** @notice Emite quando uma requisição é cancelada */
    event RequestCanceled(uint256 indexed requestId, address indexed member);

    /** @notice Emitted when a member spends and their allowance is debited */

    // -----------------------------------------
    // Requests
    // -----------------------------------------
    /**
     * @notice Cria uma requisição de gasto
     * @param categoryId ID da categoria
     * @param amount Quantidade solicitada
     * @return requestId ID gerado da requisição
     */
    function createRequest(
        uint64 categoryId,
        uint128 amount,
        string calldata note
    )
        external
        onlySpender
        categoryExists(categoryId)
        whenNotPaused
        returns (uint256 requestId)
    {
        require(amount > 0, ZeroAmountNotAllowed());
        requestId = ++_lastRequestId;
        _requests[requestId] = FamilyVaultTypes.Request({
            id: _lastRequestId,
            requester: msg.sender,
            categoryId: categoryId,
            amount: amount,
            status: FamilyVaultTypes.RequestStatus.PENDING,
            createdAt: block.timestamp,
            note: note
        });
        emit RequestCreated(requestId, msg.sender, categoryId, amount, note);
    }

    /**
     * @notice Aprova uma requisição de gasto, Deduz do saldo da categoria, mas **não** afeta o allowance do membro.
     * @param requestId ID da requisição
     * @param to Endereço que receberá os fundos
     */
    function approveRequest(
        uint256 requestId,
        address to
    ) external onlyOwner nonReentrant whenNotPaused {
        FamilyVaultTypes.Request storage request = _requests[requestId];
        require(
            request.status != FamilyVaultTypes.RequestStatus.NONE,
            RequestNotFound(requestId)
        );
        require(
            request.status == FamilyVaultTypes.RequestStatus.PENDING,
            AlreadyDecided()
        );
        request.status = FamilyVaultTypes.RequestStatus.APPROVED;
        _executeExpense(
            request.categoryId,
            request.requester,
            to,
            request.amount,
            false
        );
        emit RequestApproved(requestId, msg.sender);
    }

    /**
     * @notice Nega uma requisição de gasto
     * @param requestId ID da requisição
     * @param reason Motivo da negativa
     */
    function denyRequest(
        uint256 requestId,
        string calldata reason
    ) external onlyOwner {
        FamilyVaultTypes.Request storage request = _requests[requestId];
        require(
            request.status != FamilyVaultTypes.RequestStatus.NONE,
            RequestNotFound(requestId)
        );
        require(
            request.status == FamilyVaultTypes.RequestStatus.PENDING,
            AlreadyDecided()
        );
        request.status = FamilyVaultTypes.RequestStatus.DENIED;
        emit RequestDenied(requestId, msg.sender, reason);
    }

    /**
     * @notice Cancela uma requisicao criada
     * @param requestId id da requisição
     */
    function cancelRequest(uint256 requestId) external {
        FamilyVaultTypes.Request storage request = _requests[requestId];
        require(
            request.status != FamilyVaultTypes.RequestStatus.NONE,
            RequestNotFound(requestId)
        );
        require(request.requester == msg.sender, NotYourRequest());
        require(
            request.status == FamilyVaultTypes.RequestStatus.PENDING,
            RequestCannotBeCanceled()
        );
        request.status = FamilyVaultTypes.RequestStatus.CANCELED;
        emit RequestCanceled(requestId, msg.sender);
    }

    /**
     * @dev Essa função será migrada um indexador off-chain
     * @notice Lista as requisições pelo status
     * @param status status desejado para pesquisa
     */
    function getRequestsByStatus(
        FamilyVaultTypes.RequestStatus status
    ) external view returns (FamilyVaultTypes.Request[] memory) {
        uint256 total = _lastRequestId;
        uint256 count = 0;

        // Primeiro, contar quantas requests estão no status
        for (uint256 i = 1; i <= total; i++) {
            if (_requests[i].status == status) {
                count++;
            }
        }

        // Criar array na memória
        FamilyVaultTypes.Request[]
            memory filtered = new FamilyVaultTypes.Request[](count);
        uint256 index = 0;

        // Popular array com as requests filtradas
        for (uint256 i = 1; i <= total; i++) {
            if (_requests[i].status == status) {
                filtered[index] = _requests[i];
                index++;
            }
        }

        return filtered;
    }

    function getLastRequestId() external view returns (uint256) {
        return _lastRequestId;
    }

    /**
     * @notice Busca request pelo Id
     * @param requestId Id da Requisicao
     * @return requester
     * @return categoryId
     * @return amount
     * @return status
     * @return createdAt
     */
    function getRequestById(
        uint256 requestId
    )
        external
        view
        returns (
            address requester,
            uint64 categoryId,
            uint128 amount,
            FamilyVaultTypes.RequestStatus status,
            uint256 createdAt
        )
    {
        FamilyVaultTypes.Request storage request = _requests[requestId];
        require(request.createdAt != 0, RequestNotFound(requestId));

        requester = request.requester;
        categoryId = request.categoryId;
        amount = request.amount;
        status = request.status;
        createdAt = request.createdAt;
    }
}
