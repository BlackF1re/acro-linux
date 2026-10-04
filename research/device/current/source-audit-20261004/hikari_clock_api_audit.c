// SPDX-License-Identifier: GPL-2.0-only
/* Read-only audit: no clk_set_rate/prepare/enable or register writes. */
#include <linux/module.h>
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/of.h>
#include <dt-bindings/clock/qcom,mmcc-msm8660.h>
#include "clk-rcg.h"
#include "common.h"

static int __init audit_init(void)
{
 struct device_node *np;
 const unsigned int ids[] = { MDP_PIXEL_SRC, DSI_PIXEL_SRC, MDP_LUT_CLK };
 const char *names[] = { "MDP_PIXEL_SRC", "DSI_PIXEL_SRC", "MDP_LUT_CLK" };
 const unsigned long rates[] = {27000000, 69672960, 69673000, 200000000};
 unsigned int i,j;
 struct freq_tbl current_table[] = {
 { .freq = 25600000 },
 { .freq = 27000000 },
 { .freq = 42667000 },
 { .freq = 43192000 },
 { .freq = 48000000 },
 { .freq = 53990000 },
 { .freq = 64000000 },
 { .freq = 69300000 },
 { .freq = 69673000 },
 { .freq = 76800000 },
 { .freq = 85333000 },
 { .freq = 96000000 },
 { .freq = 100030000 },
 { .freq = 106500000 },
 { .freq = 109714000 },
 { .freq = 128000000 },
 { }
};
struct freq_tbl original_table[ARRAY_SIZE(current_table)];
unsigned int k;
memcpy(original_table, current_table, sizeof(current_table));
for(k=0;k<ARRAY_SIZE(original_table);k++)
 if(original_table[k].freq==69673000) original_table[k].freq=69672960;
pr_info("HIKARI_PATCH0044 request=69673000 current=%u original=%u\n",
 qcom_find_freq(current_table,69673000)->freq,
 qcom_find_freq(original_table,69673000)->freq);

 np=of_find_compatible_node(NULL,NULL,"qcom,mmcc-msm8660");
 if(!np) return -ENODEV;
 for(i=0;i<ARRAY_SIZE(ids);i++) {
  struct of_phandle_args args={.np=np,.args_count=1,.args={ids[i]}};
  struct clk *clk=of_clk_get_from_provider(&args);
  if(IS_ERR(clk)) { pr_err("HIKARI_CLOCK_API %s error=%ld\n",names[i],PTR_ERR(clk));continue; }
  pr_info("HIKARI_CLOCK_API %s rate=%lu\n",names[i],clk_get_rate(clk));
  for(j=0;j<ARRAY_SIZE(rates);j++)
   pr_info("HIKARI_CLOCK_API %s request=%lu rounded=%ld\n",names[i],rates[j],clk_round_rate(clk,rates[j]));
  clk_put(clk);
 }
 of_node_put(np); return 0;
}
static void __exit audit_exit(void) {}
module_init(audit_init); module_exit(audit_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Read-only Hikari clock API audit");
