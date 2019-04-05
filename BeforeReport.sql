function BeforeReport return boolean is
   ln_cont NUMBER;
   v_error VARCHAR2(1000);
begin
     IF :p_flag IN ('FACTURA','BOLETA') THEN
     	p_load_file(v_error, ln_cont);
     ELSIF :p_flag in ('NOTA DE DEBITO','NOTA DE CREDITO') THEN
     	p_load_file_nd(v_error, ln_cont);
     END IF;	
--   IF v_error IS NULL THEN
   	  load_trx_ar(:P_ORG_ID, :P_USERNAME, v_error); -->  14/05/2014
   	  srW.message('1','inserto?');
   	  IF v_error IS NULL THEN    
   	  	srw.message('1','SI');
   	     commit;
   	     :cp_cont_regis_act := 'Se han proceso y cargado ' || ln_cont || ' registro(s)';
   	  ELSE
   	  	 :cp_cont_regis_act := v_error;
   	  	 srw.message('1000', v_error);
   	  	 commit;
   	  END IF;
   --ELSE
   --	  :cp_cont_regis_act := v_error;
--   	  srw.message('1000', v_error);
   --END IF;
   return (TRUE);
end;
