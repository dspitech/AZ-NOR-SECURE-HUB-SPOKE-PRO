###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE - monitoring.tf
###############################################################################

resource "azurerm_monitor_action_group" "security" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "sec-alerts"
  tags                = var.tags

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Alerte 1 : Volume de refus Firewall élevé (tentative d'intrusion)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "fw_high_denials" {
  name                 = local.alert_fw_denial_name
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  tags                 = var.tags
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  enabled              = true
  description          = "Alerte si le Firewall refuse plus de ${var.fw_denial_threshold} connexions en 5 minutes"

  criteria {
      query = <<-QUERY
        AZFWNetworkRule
        | where Action == "Deny"
        | summarize DenialCount = count() by bin(TimeGenerated, 5m)
        | where DenialCount > ${var.fw_denial_threshold}
      QUERY
      time_aggregation_method = "Count"
      threshold               = 0
      operator                = "GreaterThan"
      failing_periods {
        minimum_failing_periods_to_trigger_alert = 1
        number_of_evaluation_periods             = 1
      }
    }

  action { action_groups = [azurerm_monitor_action_group.security.id] }
}

# Alerte 2 : Disponibilité Firewall < 95%
resource "azurerm_monitor_metric_alert" "fw_health" {
  name                = local.alert_fw_health_name
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_firewall.main.id]
  description         = "Disponibilité Firewall < 95%"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "FirewallHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 95
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}

# Alerte 3 : CPU VM Prod > 85%
resource "azurerm_monitor_metric_alert" "vm_prod_cpu" {
  name                = "alert-cpu-vm-prod"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.prod.id]
  description         = "CPU vm-prod-01 > 85%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}

# Alerte 4 : CPU VM Non-Prod > 85%
resource "azurerm_monitor_metric_alert" "vm_nonprod_cpu" {
  name                = "alert-cpu-vm-nonprod"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.nonprod.id]
  description         = "CPU vm-nonprod-01 > 85%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}
