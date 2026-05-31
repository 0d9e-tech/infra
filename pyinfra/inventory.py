defaults = {"ssh_user": "prokop", "_sudo": True}

my_hosts = [
    ("experiler", {"ssh_hostname": "2a00:5c20:200:c1:8aa2:9eff:fe5e:9006", **defaults}),
    ("pidimidi", {"ssh_hostname": "2a00:5c20:200:c1:ba27:ebff:fe1f:758b", **defaults}),
    ("boxolie", {"ssh_hostname": "2a02:768:71c:659e:8aa2:9eff:fe24:5749", **defaults}),
]
