graph TD
    A[Raffle Draw Triggered] --> B[Get Current Ledger Data]
    B --> C[Ledger Sequence]
    B --> D[Ledger Timestamp]
    A --> E[Raffle ID]
    A --> F[Current Participants]

    C --> G[Combine Entropy Sources]
    D --> G
    E --> G
    F --> G

    G --> H[Create Data Buffer]
    H --> I[Pack Entropy as u64]
    H --> J[Pack Participant Count as u32]
    H --> K[Pack Raffle ID as u64]

    I --> L[SHA-256 Hash]
    J --> L
    K --> L

    L --> M[Extract First 4 Bytes]
    M --> N[Convert to u32]
    N --> O[Modulo Operation]
    F --> O[participants.length]

    O --> P[Select Winner Index]
    P --> Q[Get Winner Address]
    Q --> R[Remove from Pool]
    R --> S{More Winners Needed?}
    S -->|Yes| O
    S -->|No| T[Return Winners List]

    style A fill:#e1f5fe
    style L fill:#fff3e0
    style O fill:#f3e5f5
    style T fill:#e8f5e8
```

```mermaid
sequenceDiagram
    participant U as User
    participant C as Contract
    participant L as Ledger
    participant V as Verifier

    U->>C: Enter Raffle
    C->>C: Add to participants
    Note over C: Deadline reached

    U->>C: Trigger Draw
    C->>L: Get current ledger data
    L-->>C: sequence + timestamp
    C->>C: Compute entropy = seq + ts + raffle_id

    loop For each winner
        C->>C: Create hash input buffer
        C->>C: SHA-256 hash
        C->>C: Extract random u32
        C->>C: Select winner via modulo
        C->>C: Remove winner from pool
    end

    C->>C: Store winners on-chain
    C-->>U: Winners announced

    V->>L: Get ledger data
    V->>C: Get participants
    V->>V: Recompute winners
    V->>V: Compare with announced winners
    V-->>U: Verification result
```

```mermaid
graph TD
    subgraph "Entropy Sources"
        A1[Ledger Sequence<br/>32+ bits]
        A2[Ledger Timestamp<br/>30+ bits]
        A3[Raffle ID<br/>32+ bits]
    end

    subgraph "Mixing Function"
        B1[SHA-256<br/>Cryptographic Hash]
    end

    subgraph "Output Distribution"
        C1[Uniform Random<br/>0 to 2^32-1]
        C2[Modulo Mapping<br/>to Participant Index]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1
    B1 --> C1
    C1 --> C2

    style B1 fill:#fff3e0,stroke:#ff9800,stroke-width:3px
    style C1 fill:#e8f5e8,stroke:#4caf50,stroke-width:2px
```

```mermaid
pie title Security Risk Assessment
    "Very Low" : 40
    "Low" : 45
    "Medium" : 15
```

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Active: Raffle starts
    Active --> Drawing: Deadline reached
    Drawing --> Completed: Winners selected
    Completed --> [*]

    Drawing --> Failed: Error in draw
    Failed --> [*]

    note right of Drawing : Uses ledger entropy
    note right of Completed : Results verifiable
```

```mermaid
graph LR
    subgraph "User Verification"
        A[Get Raffle Data] --> B[Get Ledger Data]
        B --> C[Recompute Winners]
        C --> D[Compare Results]
    end

    subgraph "Auditor Verification"
        E[Batch Process] --> F[Automated Scripts]
        F --> G[Generate Reports]
    end

    subgraph "Integration"
        H[API Endpoints] --> I[Webhook Callbacks]
        I --> J[Database Storage]
    end

    D --> K[Display Proof]
    G --> L[Publish Audit]
    J --> M[Query Interface]

    style A fill:#e3f2fd
    style E fill:#f3e5f5
    style H fill:#e8f5e8