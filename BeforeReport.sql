function BeforeReport return boolean is
   ln_cont NUMBER;
   v_error VARCHAR2(1000);
   v_lote_id number;
   v_respond_sku varchar2(4000);
   v_respond_credito varchar2(4000);
begin
     IF :p_flag IN ('FACTURA','BOLETA') THEN
     	p_load_file(v_error, ln_cont);
     ELSIF :p_flag in ('NOTA DE DEBITO','NOTA DE CREDITO') THEN
     	p_load_file_nd(v_error, ln_cont);
     END IF;

	    --- Carga en la interface AR ---
   	  load_trx_ar(:P_ORG_ID, :P_USERNAME,v_lote_id ,v_error); 
   	  
   	  :P_LOTE := v_lote_id;
   	  
   	  srW.message('1','inserto?');
   	  IF v_error IS NULL THEN    
   	  	
   	  --- Valida SKU ---
   	  IF v_error is null and v_lote_id > 0  then 
   	  INTERSF.OPT_PROG_UXPOS_SIGIC_PKG.PRC_VALIDA_SKU (v_lote_id,-1,v_respond_sku);
   	  END IF;
   	  
   	  --- Valida Linea de credito ---
   	  IF v_error is null and v_lote_id > 0  then 
   	  INTERSF.OPT_PROG_UXPOS_SIGIC_PKG.PRC_VALIDA_LINEA_CREDITO (v_lote_id,-1,v_respond_credito);
   	  END IF;
   	  
   	  srw.message('1000', 'ID_LOTE = '||v_lote_id);
   	     	 
   	  srw.message('1000', v_respond_sku);
   	  
   	  srw.message('1000', v_respond_credito);
   	  
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
