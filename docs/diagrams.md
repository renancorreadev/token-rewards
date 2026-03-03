# TokenRewards — Diagramas

## 1. Arquitetura do Contrato (Herança)

```mermaid
classDiagram
    ERC1155 <|-- ERC1155Burnable
    ERC1155 <|-- ERC1155Pausable
    ERC1155 <|-- ERC1155Supply
    AccessControl <|-- TokenRewards
    ERC1155Burnable <|-- TokenRewards
    ERC1155Pausable <|-- TokenRewards
    ERC1155Supply <|-- TokenRewards

    class TokenRewards {
        +uint256 TOKEN_A = 0
        +uint256 TOKEN_B = 1
        +bytes32 MINTER_ROLE
        +bytes32 DISTRIBUTOR_ROLE
        +mintTokenA(to, amount)
        +batchMintTokenA(recipients, amounts)
        +distributeTokenB(totalAmount)
        +getHolders() address[]
        +getHoldersCount() uint256
        +isTokenAHolder(account) bool
        +pause()
        +unpause()
        +setURI(newURI)
    }

    class ERC1155Burnable {
        +burn(account, id, value)
        +burnBatch(account, ids, values)
    }

    class ERC1155Pausable {
        +paused() bool
    }

    class ERC1155Supply {
        +totalSupply(id) uint256
        +exists(id) bool
    }

    class AccessControl {
        +hasRole(role, account) bool
        +grantRole(role, account)
        +revokeRole(role, account)
    }
```

## 2. Sistema de Roles (Access Control)

```mermaid
flowchart TD
    subgraph Roles
        ADMIN["DEFAULT_ADMIN_ROLE<br/>(0x00)"]
        MINTER["MINTER_ROLE"]
        DISTRIBUTOR["DISTRIBUTOR_ROLE"]
    end

    ADMIN -->|gerencia| MINTER
    ADMIN -->|gerencia| DISTRIBUTOR
    ADMIN -->|gerencia| ADMIN

    subgraph "Permissões ADMIN"
        A1[pause / unpause]
        A2[setURI]
        A3[grantRole / revokeRole]
    end

    subgraph "Permissões MINTER"
        M1[mintTokenA]
        M2[batchMintTokenA]
    end

    subgraph "Permissões DISTRIBUTOR"
        D1[distributeTokenB]
    end

    ADMIN --> A1
    ADMIN --> A2
    ADMIN --> A3
    MINTER --> M1
    MINTER --> M2
    DISTRIBUTOR --> D1

    style ADMIN fill:#e74c3c,color:#fff
    style MINTER fill:#3498db,color:#fff
    style DISTRIBUTOR fill:#2ecc71,color:#fff
```

## 3. Fluxo de Mint Token A

```mermaid
sequenceDiagram
    actor Minter
    participant Contract as TokenRewards
    participant Holders as _holders[]

    Minter->>Contract: mintTokenA(userA, 100)
    activate Contract
    Contract->>Contract: verificar MINTER_ROLE
    Contract->>Contract: verificar address != 0x0
    Contract->>Contract: verificar amount > 0
    Contract->>Contract: _mint(userA, TOKEN_A, 100)
    Contract->>Holders: _addHolder(userA)
    Contract-->>Minter: emit TokenAMinted(userA, 100)
    deactivate Contract

    Note over Holders: holders = [userA]

    Minter->>Contract: mintTokenA(userB, 500)
    activate Contract
    Contract->>Contract: _mint(userB, TOKEN_A, 500)
    Contract->>Holders: _addHolder(userB)
    Contract-->>Minter: emit TokenAMinted(userB, 500)
    deactivate Contract

    Note over Holders: holders = [userA, userB]
```

## 4. Fluxo de Distribuição Token B (Reward)

```mermaid
sequenceDiagram
    actor Distributor
    participant Contract as TokenRewards
    participant Math as Math.mulDiv

    Note over Contract: holders = [Alice(300), Bob(500), Carol(200)]<br/>totalSupply(TOKEN_A) = 1000

    Distributor->>Contract: distributeTokenB(1000)
    activate Contract
    Contract->>Contract: verificar DISTRIBUTOR_ROLE
    Contract->>Contract: verificar !paused
    Contract->>Contract: verificar totalAmount > 0
    Contract->>Contract: verificar holdersCount > 0
    Contract->>Contract: verificar totalSupply > 0

    loop Para cada holder
        Contract->>Math: mulDiv(1000, holderBalance, 1000)
        Math-->>Contract: reward

        Note right of Math: Alice: 1000 × 300 / 1000 = 300
        Note right of Math: Bob: 1000 × 500 / 1000 = 500
        Note right of Math: Carol: 1000 × 200 / 1000 = 200

        Contract->>Contract: _mint(holder, TOKEN_B, reward)
    end

    Contract-->>Distributor: emit TokenBDistributed(1000, 1000, 3)
    deactivate Contract
```

## 5. Fluxo de Distribuição com Dust

```mermaid
sequenceDiagram
    actor Distributor
    participant Contract as TokenRewards
    participant Math as Math.mulDiv

    Note over Contract: holders = [UserA(100), UserB(500)]<br/>totalSupply(TOKEN_A) = 600

    Distributor->>Contract: distributeTokenB(1000)
    activate Contract

    Contract->>Math: mulDiv(1000, 100, 600)
    Math-->>Contract: 166 (floor de 166.66...)

    Contract->>Contract: _mint(UserA, TOKEN_B, 166)

    Contract->>Math: mulDiv(1000, 500, 600)
    Math-->>Contract: 833 (floor de 833.33...)

    Contract->>Contract: _mint(UserB, TOKEN_B, 833)

    Note over Contract: totalMinted = 166 + 833 = 999<br/>dust = 1000 - 999 = 1 (não mintado)

    Contract-->>Distributor: emit TokenBDistributed(1000, 999, 2)
    deactivate Contract
```

## 6. Tracking de Holders (Add / Remove)

```mermaid
flowchart TD
    subgraph "_update() override"
        CHECK{Token ID == TOKEN_A?}
        CHECK -->|Não| SKIP[Ignora tracking]
        CHECK -->|Sim| FROM_CHECK

        FROM_CHECK{from != address 0<br/>AND balance == 0?}
        FROM_CHECK -->|Sim| REMOVE["_removeHolder(from)<br/>swap-and-pop O(1)"]
        FROM_CHECK -->|Não| TO_CHECK

        TO_CHECK{to != address 0<br/>AND !_isHolder?}
        TO_CHECK -->|Sim| ADD["_addHolder(to)<br/>push O(1)"]
        TO_CHECK -->|Não| DONE[Fim]

        REMOVE --> TO_CHECK
        ADD --> DONE
    end

    style CHECK fill:#f39c12,color:#fff
    style REMOVE fill:#e74c3c,color:#fff
    style ADD fill:#2ecc71,color:#fff
```

## 7. Ciclo de Vida Completo

```mermaid
flowchart LR
    DEPLOY["Deploy<br/>(admin, uri)"] --> SETUP["Setup Roles<br/>grantRole()"]
    SETUP --> MINT["Mint Token A<br/>mintTokenA()"]
    MINT --> DISTRIBUTE["Distribuir Token B<br/>distributeTokenB()"]
    DISTRIBUTE -->|"periódico"| DISTRIBUTE

    MINT -->|"novos membros"| MINT

    DISTRIBUTE --> BURN["Burn (opcional)<br/>burn()"]
    DISTRIBUTE --> TRANSFER["Transfer (opcional)<br/>safeTransferFrom()"]

    PAUSE["pause()"] -.->|"bloqueia"| MINT
    PAUSE -.->|"bloqueia"| DISTRIBUTE
    PAUSE -.->|"bloqueia"| BURN
    PAUSE -.->|"bloqueia"| TRANSFER
    UNPAUSE["unpause()"] -.->|"desbloqueia"| MINT

    style DEPLOY fill:#9b59b6,color:#fff
    style MINT fill:#3498db,color:#fff
    style DISTRIBUTE fill:#2ecc71,color:#fff
    style PAUSE fill:#e74c3c,color:#fff
    style UNPAUSE fill:#27ae60,color:#fff
```

## 8. Estrutura do Projeto

```mermaid
flowchart TD
    subgraph src
        TR[TokenRewards.sol]
    end

    subgraph test
        T1[Constructor.t.sol]
        T2[MintTokenA.t.sol]
        T3[BatchMintTokenA.t.sol]
        T4[DistributeTokenB.t.sol]
        T5[Transfer.t.sol]
        T6[Burn.t.sol]
        T7[Pause.t.sol]

        subgraph security
            E[echidna/TokenRewardsEchidna.sol]
            H[halmos/TokenRewardsHalmos.t.sol]
        end
    end

    subgraph script
        S[TokenRewards.s.sol]
    end

    TR --> T1 & T2 & T3 & T4 & T5 & T6 & T7
    TR --> E & H
    TR --> S

    style TR fill:#e74c3c,color:#fff
    style S fill:#9b59b6,color:#fff
```
