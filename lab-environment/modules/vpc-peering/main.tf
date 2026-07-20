# ---------------------------------------------------------------------------
# Bi-directional VPC Peering
# ---------------------------------------------------------------------------

resource "google_compute_network_peering" "a_to_b" {
  name         = "${var.vpc_a_name}-to-${var.vpc_b_name}"
  network      = var.vpc_a_self_link
  peer_network = var.vpc_b_self_link

  export_custom_routes = var.export_custom_routes
  import_custom_routes = var.import_custom_routes
}

resource "google_compute_network_peering" "b_to_a" {
  name         = "${var.vpc_b_name}-to-${var.vpc_a_name}"
  network      = var.vpc_b_self_link
  peer_network = var.vpc_a_self_link

  export_custom_routes = var.export_custom_routes
  import_custom_routes = var.import_custom_routes

  depends_on = [google_compute_network_peering.a_to_b]
}
