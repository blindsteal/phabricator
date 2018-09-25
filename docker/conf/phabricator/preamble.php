<?php

// Overwrite REMOTE_ADDR with the value in the "X-Forwarded-For" HTTP header.

// Only do this if you're certain the request is coming from a loadbalancer!
// If the request came directly from a client, doing this will allow them to
// them spoof any remote address.

// The header may contain a list of IPs, like "1.2.3.4, 4.5.6.7", if the
// request the load balancer received also had this header.

if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
  $forwarded_for = $_SERVER['HTTP_X_FORWARDED_FOR'];
  if ($forwarded_for) {
    $forwarded_for = explode(',', $forwarded_for);
    $forwarded_for = end($forwarded_for);
    $forwarded_for = trim($forwarded_for);
    $_SERVER['REMOTE_ADDR'] = $forwarded_for;
  }
}

// Tell PHP that it's running behind a HTTPS loadbalancer.

$_SERVER['HTTPS'] = true;