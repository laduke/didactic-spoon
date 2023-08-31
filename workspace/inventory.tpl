[wan_nodes]
%{ for ip in wan_nodes ~}
${ip}
%{ endfor ~}

[zt_nodes]
%{ for ip in zt_nodes ~}
${ip}
%{ endfor ~}
