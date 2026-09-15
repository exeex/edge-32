  always @(posedge clk) begin
    if(if_id_fire) begin
      {id_frs0,id_frs1,id_frs2,id_write_rd} <=
        {if_frs0,if_frs1,if_frs2,if_write_rd};
      {id_uses_fpr,id_rd_gpr,id_rd_fpr,id_csr_write} <=
        {if_uses_fpr,if_rd_gpr,if_rd_fpr,if_csr_write};
      id_decoded_class<=if_decoded_class; id_decoded_legal<=if_decoded_legal;
    end
  end
