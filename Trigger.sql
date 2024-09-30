CREATE OR REPLACE TRIGGER ISLBAS.DBT_STFACMAS_USDLMT
   AFTER UPDATE OF acstat,curbal
   ON islbas.stfacmas
   REFERENCING NEW AS NEW OLD AS OLD
   FOR EACH ROW
WHEN (
SUBSTR (OLD.actype, 1, 1) IN ('I', 'T')
      )
DECLARE
   v_count   NUMBER (6);
   v_lcamt   NUMBER (16) := 0;
/*
-- created for head office credit line. if account type is Closed without disburse then
-- it will make available limit in stbrnlmt table
*/
BEGIN
   IF UPDATING THEN
      IF :NEW.acstat IN ('CLS', 'CAN') THEN
         IF NVL (:OLD.regone, 'R') IN ('R', 'O') THEN
            -- Check the amount Disburse is completed or not
            SELECT COUNT (actnum)
              INTO v_count
              FROM islbas.stfetran
             WHERE brancd = :OLD.brancd
               AND actype = :OLD.actype
               AND actnum = :OLD.actnum
               AND balflg = 'Y'
               AND rvdocnum IS NULL;

            -- END  Disburse  Check
            IF SUBSTR (:OLD.actype, 1, 1) IN ('T') THEN
               -- Getting LC Amount
               BEGIN
                  SELECT SUM (NVL (rmamtl, 0))
                    INTO v_lcamt
                    FROM islbas.stilcmas
                   WHERE brancd = :OLD.brancd
                     AND actype = :OLD.actype
                     AND actnum = :OLD.actnum
                     AND lcstat = 'ISS';
               EXCEPTION
                  WHEN OTHERS THEN
                     v_lcamt := 0;
               END;
            -- End Getting LC Amount
            END IF;

            IF v_count = 0 THEN
               IF v_lcamt > 0 THEN
                  BEGIN
                     IF NVL (:OLD.regone, 'R') = 'R' THEN
                        UPDATE islbas.stbrnlmt
                           SET usdlmt = usdlmt - v_lcamt
                         WHERE brancd = :OLD.brancd
                           AND actype = :OLD.actype
                           AND cuscod = :OLD.cuscod
                           AND usdlmt >= v_lcamt;
                     ELSIF NVL (:OLD.regone, 'R') = 'O' THEN
                        UPDATE islbas.stbrnlm1
                           SET usdlmt = usdlmt - v_lcamt
                         WHERE brancd = :OLD.brancd
                           AND actype = :OLD.actype
                           AND cuscod = :OLD.cuscod
                           AND NVL(srlnum,1) =  :OLD.srlnum   -- Added by Jahanara Begum as on 12/11/2018 for updating onetine limit
                           AND usdlmt >= v_lcamt;
                     END IF;
                  /*
                  IF SQL%ROWCOUNT = 0 THEN
                     raise_application_error(-20301,'>Usdlmt Not Updated,Please Check...');
                  END IF;
                  */
                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error
                                      (-20301,
                                       '>>Usdlmt Not Updated,Please Check...'
                                      );
                  END;
               ELSIF v_lcamt = 0 THEN
                  BEGIN
                     /*IF NVL (:OLD.regone, 'R') = 'R' THEN
                        UPDATE islbas.stbrnlmt
                           SET usdlmt = usdlmt - :OLD.depamt
                         WHERE brancd = :OLD.brancd
                           AND actype = :OLD.actype
                           AND cuscod = :OLD.cuscod
                           AND usdlmt >= :OLD.depamt;*/----comment by maruf 08012023
                    IF NVL (:OLD.regone, 'R') = 'O' THEN
                        UPDATE islbas.stbrnlm1
                           SET usdlmt = usdlmt - :OLD.depamt
                         WHERE brancd = :OLD.brancd
                           AND actype = :OLD.actype
                           AND cuscod = :OLD.cuscod
                           AND NVL(srlnum,1) =  :OLD.srlnum   -- Added by Jahanara Begum as on 12/11/2018 for updating onetine limit
                           AND usdlmt >= :OLD.depamt;
                     END IF;
                  /*
                  IF SQL%ROWCOUNT = 0 THEN
                     raise_application_error(-20301,'>>>Usdlmt Not Updated,Please Check...');
                  END IF;
                  */
                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error
                                    (-20301,
                                     '>>>>Usdlmt Not Updated,Please Check...'
                                    );
                  END;
               END IF;
            END IF;
         END IF;
      END IF;
   END IF;
END;
/
SHOW ERRORS;
