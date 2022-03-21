(define-public (pay (id uint) (price uint))
    (begin
        (try! (stx-transfer? (/ (* price u50) u10000) tx-sender 'SP1EV6DEGJYN4NC4GS94MTXKF8PAQ5ZNA4QHJ2VZ6))
        (try! (stx-transfer? (/ (* price u260) u10000) tx-sender 'SP1WPW265R43CEDYQSY1NMPE2C2EN73A7HY8PBNDM))
        (try! (stx-transfer? (/ (* price u165) u10000) tx-sender 'SP2H2ZB08EW097TPDQPDPPJ6B73YAZS4V2KNSDC04))
        (try! (stx-transfer? (/ (* price u25) u10000) tx-sender 'SP3QX0PWSP98Y7MZ0T25ERVP2JVAP3QSXZYJKWPY9))
        (try! (stx-transfer? (/ (* price u100) u10000) tx-sender 'SPNWZ5V2TPWGQGVDR6T7B6RQ4XMGZ4PXTEE0VQ0S))
        (ok true)))