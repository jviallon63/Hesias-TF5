---
title: "📚 TP Terraform"
layout: home
---

Bienvenue dans les travaux pratiques Terraform.

---

## 🧪 Liste des TP

{% assign tp_pages = site.pages | where_exp: "p", "p.dir == '/tp/'" | sort: "name" %}
{% for tp in tp_pages %}
- [{{ tp.title }}]({{ tp.url | relative_url }})
{% endfor %}