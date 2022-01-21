// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Generic countermeasure interface for hardened FSM
//
// This contains a proxy class and store the object in sec_cm_pkg, which can be used in vseq to
// control inject_fault and restore_fault
interface prim_sparse_fsm_flop_if #(
  parameter int Width = 2
) (
  input clk_i,
  input rst_ni);

  localparam int MaxFlipBits = 2;

  string msg_id = $sformatf("%m");

  string path = dv_utils_pkg::get_parent_hier($sformatf("%m"));
  string signal_forced = $sformatf("%s.state_o", path);

  class prim_sparse_fsm_flop_if_proxy extends sec_cm_pkg::sec_cm_base_if_proxy;
    `uvm_object_new

    logic[Width-1:0] orig_value;

    virtual task inject_fault();
      logic[Width-1:0] force_value;

      @(negedge clk_i);
      `DV_CHECK(uvm_hdl_read(signal_forced, orig_value))
      `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(force_value,
          $countones(force_value ^ orig_value) inside {[1: MaxFlipBits]};)

      `DV_CHECK(uvm_hdl_deposit(signal_forced, force_value))
      `uvm_info(msg_id, $sformatf("Forcing %s from %0d to %0d",
                                  signal_forced, orig_value, force_value), UVM_LOW)

      @(posedge clk_i);
    endtask

    virtual task restore_fault();
      `DV_CHECK(uvm_hdl_deposit(signal_forced, orig_value))
      `uvm_info(msg_id, $sformatf("Forcing %s to original value %0d", signal_forced, orig_value),
                UVM_LOW)
    endtask
  endclass

  prim_sparse_fsm_flop_if_proxy if_proxy;

  initial begin
    `DV_CHECK_FATAL(uvm_hdl_check_path(signal_forced), , msg_id)

    // Store the proxy object for TB to use
    if_proxy = new("if_proxy");
    if_proxy.sec_cm_type = sec_cm_pkg::SecCmPrimSparseFsmFlop;
    if_proxy.path = path;
    sec_cm_pkg::sec_cm_if_proxy_q.push_back(if_proxy);

    `uvm_info(msg_id, $sformatf("Interface proxy class is added for %s", path), UVM_MEDIUM)
  end
endinterface