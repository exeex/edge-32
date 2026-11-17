// A legal putchar completes immediately. Do not route slow-unit completion
// (cache/fence, LSU, MUL/DIV) or their fault mux through the console event.
assign ex_wb.putchar = ex_issue_ok && is_edge_putchar && csr_write;
