                GLOBAL CONSENSUS DOMAIN
         (expensive — must be agreed by everyone)

           +----------------------------------+
           |        Zenon Ordering Layer      |
           |                                  |
           |   append-only sequence of claims |
           |                                  |
           |   C1 → C2 → C3 → C4 → C5 → ...   |
           +------------------┬---------------+
                              │
                              │ canonical event log
                              ▼

        -------------------------------------------------
            LOCAL DETERMINISTIC COMPUTATION DOMAIN
             (cheap — recomputed independently)

   +-------------------+   +-------------------+   +-------------------+
   |   Market Runtime  |   |   Bridge Runtime  |   |   AI Runtime      |
   |                   |   |                   |   |                   |
   | order matching    |   | proof validation  |   | agent claims      |
   | settlement        |   | token minting     |   | commitments       |
   | liquidity state   |   | bridge balances   |   | scoring           |
   +---------┬---------+   +---------┬---------+   +---------┬---------+
             │                       │                       │
             ▼                       ▼                       ▼

       Derived Market State     Derived Bridge State     Derived AI State
