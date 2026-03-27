# Filter Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all `= true` fallbacks in the 11 non-enUS locale files for filter-related keys with natural, game-appropriate translated strings so players can type filter expressions in their native language.

**Architecture:** Pure locale file edits — no Lua code changes. Each locale file has a compact `= true` block near the end starting with `-- Advanced filter language (Feature #18) — translate these strings`. Each task replaces that block with expanded translations. Single-letter alias keys (`filter.key.zone.z`, etc.) remain `= true` by design.

**Tech Stack:** Lua, AceLocale, WoW TBC Anniversary

---

## File Structure

- Modify: `Locales/deDE.lua`
- Modify: `Locales/frFR.lua`
- Modify: `Locales/esES.lua`
- Modify: `Locales/esMX.lua`
- Modify: `Locales/zhCN.lua`
- Modify: `Locales/zhTW.lua`
- Modify: `Locales/ptBR.lua`
- Modify: `Locales/itIT.lua`
- Modify: `Locales/koKR.lua`
- Modify: `Locales/ruRU.lua`
- Modify: `Locales/jaJP.lua`
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

## Replacement Format

Each task replaces the entire block from `-- Advanced filter language (Feature #18) — translate these strings` through the final `L["filter.help.example.9.note"]=true` line with the expanded form shown in each task. The replacement keeps alias keys as `= true` (one per line) and gives full-name keys their translated values.

---

### Task 1: deDE (German)

**Files:**
- Modify: `Locales/deDE.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/deDE.lua` and find the line starting with `-- Advanced filter language (Feature #18)`. Note its line number.

- [ ] **Step 2: Replace the filter block**

  Replace the entire `-- Advanced filter language` block (from the comment through `L["filter.help.example.9.note"]=true`) with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "Gebiet"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Gebietsname (Teilstring-Suche)"
  L["filter.key.title"]        = "Titel"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Questtitel (Teilstring-Suche)"
  L["filter.key.chain"]        = "Questreihe"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Questreihentitel (Teilstring-Suche)"
  L["filter.key.player"]       = "Spieler"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Gruppenname (nur Gruppe/Geteilt-Reiter)"
  L["filter.key.level"]        = "Stufe"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Empfohlene Queststufe"
  L["filter.key.step"]         = "Schritt"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Schrittnummer der Questreihe"
  L["filter.key.group"]        = "Gruppe"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Gruppenanforderung (Ja, Nein, 2-5)"
  L["filter.key.type"]         = "Typ"
  L["filter.key.type.desc"]    = "Questtyp — Questreihe, Gruppe, Solo, Zeitbegrenzt, Eskorte, Verlies, Schlachtzug, Elite, Tagesquest, pvp, Töten, Sammeln, Interagieren"
  L["filter.key.status"]       = "Status"
  L["filter.key.status.desc"]  = "Queststatus (abgeschlossen, unvollständig, fehlgeschlagen)"
  L["filter.key.tracked"]      = "Verfolgt"
  L["filter.key.tracked.desc"] = "Auf der Minikarte verfolgt (Ja, Nein; nur Mein-Reiter)"
  L["filter.val.yes"]          = "Ja"
  L["filter.val.no"]           = "Nein"
  L["filter.val.complete"]     = "abgeschlossen"
  L["filter.val.incomplete"]   = "unvollständig"
  L["filter.val.failed"]       = "fehlgeschlagen"
  L["filter.val.chain"]        = "Questreihe"
  L["filter.val.group"]        = "Gruppe"
  L["filter.val.solo"]         = "Solo"
  L["filter.val.timed"]        = "Zeitbegrenzt"
  L["filter.val.escort"]       = "Eskorte"
  L["filter.val.dungeon"]      = "Verlies"
  L["filter.val.raid"]         = "Schlachtzug"
  L["filter.val.elite"]        = "Elite"
  L["filter.val.daily"]        = "Tagesquest"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "Töten"
  L["filter.val.gather"]       = "Sammeln"
  L["filter.val.interact"]     = "Interagieren"
  L["filter.err.UNKNOWN_KEY"]      = "unbekannter Filterschlüssel '%s'"
  L["filter.err.INVALID_OPERATOR"] = "Operator '%s' kann nicht mit '%s' verwendet werden"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' erfordert ein numerisches Feld"
  L["filter.err.UNCLOSED_QUOTE"]   = "nicht geschlossenes Anführungszeichen im Filterausdruck"
  L["filter.err.EMPTY_VALUE"]      = "fehlender Wert nach '%s'"
  L["filter.err.INVALID_NUMBER"]   = "Zahl für '%s' erwartet, '%s' erhalten"
  L["filter.err.RANGE_REVERSED"]   = "ungültiger Bereich: Min (%s) muss <= Max (%s) sein"
  L["filter.err.INVALID_ENUM"]     = "'%s' ist kein gültiger Wert für '%s'"
  L["filter.err.label"]            = "Filterfehler: %s"
  L["filter.help.title"]                = "SQ-Filtersyntax"
  L["filter.help.intro"]                = "Filterbedingung eingeben und Enter drücken, um sie als dauerhaftes Label anzuwenden. Label mit [x] schließen. Mehrere Filter werden mit UND verknüpft."
  L["filter.help.section.syntax"]       = "Syntax"
  L["filter.help.section.keys"]         = "Unterstützte Schlüssel"
  L["filter.help.section.examples"]     = "Beispiele"
  L["filter.help.col.key"]              = "Schlüssel"
  L["filter.help.col.aliases"]          = "Aliase"
  L["filter.help.col.desc"]             = "Beschreibung"
  L["filter.help.example.1"]            = "Stufe>=60"
  L["filter.help.example.1.note"]       = "Quests ab Stufe 60 anzeigen"
  L["filter.help.example.2"]            = "Stufe=58..62"
  L["filter.help.example.2.note"]       = "Quests im Stufenbereich 58-62 anzeigen"
  L["filter.help.example.3"]            = "Gebiet=Elwynn|Todesminen"
  L["filter.help.example.3.note"]       = "Quests in Elwynn-Forst ODER den Todesminen anzeigen"
  L["filter.help.example.4"]            = "Status=unvollständig"
  L["filter.help.example.4.note"]       = "Nur unvollständige Quests anzeigen"
  L["filter.help.example.5"]            = "Typ=Questreihe"
  L["filter.help.example.5.note"]       = "Nur Questreihen anzeigen"
  L["filter.help.example.6"]            = "Gebiet=\"Höllenfeuerhalbinsel\""
  L["filter.help.example.6.note"]       = "Wert in Anführungszeichen (bei Werten mit Leerzeichen)"
  L["filter.help.type.note"]            = "Töten, Sammeln und Interagieren treffen auf Quests zu, die mindestens ein entsprechendes Ziel haben — Quests können mehreren Typen entsprechen. Typfilter erfordern das Add-on Questie oder Quest Weaver."
  L["filter.help.example.7"]            = "Typ=Verlies"
  L["filter.help.example.7.note"]       = "Nur Verlies-Quests anzeigen (erfordert Questie oder Quest Weaver)"
  L["filter.help.example.8"]            = "Typ=Töten"
  L["filter.help.example.8.note"]       = "Quests mit mindestens einem Töten-Ziel anzeigen"
  L["filter.help.example.9"]            = "Typ=Tagesquest"
  L["filter.help.example.9.note"]       = "Nur Tagesquests anzeigen"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "Gebiet" Locales/deDE.lua`
  Expected: 3 or more (zone key, desc, example 3, example 6)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/deDE.lua
  git commit -m "feat(locale): add deDE filter translations"
  ```

---

### Task 2: frFR (French)

**Files:**
- Modify: `Locales/frFR.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/frFR.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "zone"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Nom de zone (correspondance partielle)"
  L["filter.key.title"]        = "titre"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Titre de quête (correspondance partielle)"
  L["filter.key.chain"]        = "série"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Titre de série (correspondance partielle)"
  L["filter.key.player"]       = "joueur"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Nom du membre (onglets Groupe/Partagé uniquement)"
  L["filter.key.level"]        = "niveau"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Niveau recommandé de la quête"
  L["filter.key.step"]         = "étape"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Numéro d'étape dans la série"
  L["filter.key.group"]        = "groupe"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Exigence de groupe (oui, non, 2-5)"
  L["filter.key.type"]         = "type"
  L["filter.key.type.desc"]    = "Type de quête — série, groupe, solo, chronométré, escorte, donjon, raid, élite, journalière, pvp, tuer, collecter, interagir"
  L["filter.key.status"]       = "statut"
  L["filter.key.status.desc"]  = "Statut de la quête (complète, incomplète, échouée)"
  L["filter.key.tracked"]      = "suivi"
  L["filter.key.tracked.desc"] = "Suivi sur la minicarte (oui, non ; onglet Moi uniquement)"
  L["filter.val.yes"]          = "oui"
  L["filter.val.no"]           = "non"
  L["filter.val.complete"]     = "complète"
  L["filter.val.incomplete"]   = "incomplète"
  L["filter.val.failed"]       = "échouée"
  L["filter.val.chain"]        = "série"
  L["filter.val.group"]        = "groupe"
  L["filter.val.solo"]         = "solo"
  L["filter.val.timed"]        = "chronométré"
  L["filter.val.escort"]       = "escorte"
  L["filter.val.dungeon"]      = "donjon"
  L["filter.val.raid"]         = "raid"
  L["filter.val.elite"]        = "élite"
  L["filter.val.daily"]        = "journalière"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "tuer"
  L["filter.val.gather"]       = "collecter"
  L["filter.val.interact"]     = "interagir"
  L["filter.err.UNKNOWN_KEY"]      = "clé de filtre inconnue '%s'"
  L["filter.err.INVALID_OPERATOR"] = "l'opérateur '%s' ne peut pas être utilisé avec '%s'"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' nécessite un champ numérique"
  L["filter.err.UNCLOSED_QUOTE"]   = "guillemet non fermé dans l'expression de filtre"
  L["filter.err.EMPTY_VALUE"]      = "valeur manquante après '%s'"
  L["filter.err.INVALID_NUMBER"]   = "un nombre est attendu pour '%s', mais '%s' a été reçu"
  L["filter.err.RANGE_REVERSED"]   = "plage invalide : le min (%s) doit être <= au max (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' n'est pas une valeur valide pour '%s'"
  L["filter.err.label"]            = "Erreur de filtre : %s"
  L["filter.help.title"]                = "Syntaxe des filtres SQ"
  L["filter.help.intro"]                = "Saisissez une expression de filtre et appuyez sur Entrée pour l'appliquer comme étiquette persistante. Fermez une étiquette avec [x]. Plusieurs filtres sont combinés avec ET."
  L["filter.help.section.syntax"]       = "Syntaxe"
  L["filter.help.section.keys"]         = "Clés supportées"
  L["filter.help.section.examples"]     = "Exemples"
  L["filter.help.col.key"]              = "Clé"
  L["filter.help.col.aliases"]          = "Alias"
  L["filter.help.col.desc"]             = "Description"
  L["filter.help.example.1"]            = "niveau>=60"
  L["filter.help.example.1.note"]       = "Afficher les quêtes de niveau 60 ou plus"
  L["filter.help.example.2"]            = "niveau=58..62"
  L["filter.help.example.2.note"]       = "Afficher les quêtes de niveau 58 à 62"
  L["filter.help.example.3"]            = "zone=Elwynn|Mortemines"
  L["filter.help.example.3.note"]       = "Afficher les quêtes en Forêt d'Elwynn OU dans les Mortemines"
  L["filter.help.example.4"]            = "statut=incomplète"
  L["filter.help.example.4.note"]       = "Afficher uniquement les quêtes incomplètes"
  L["filter.help.example.5"]            = "type=série"
  L["filter.help.example.5.note"]       = "Afficher uniquement les quêtes en série"
  L["filter.help.example.6"]            = "zone=\"Péninsule des Flammes infernales\""
  L["filter.help.example.6.note"]       = "Valeur entre guillemets (à utiliser si la valeur contient des espaces)"
  L["filter.help.type.note"]            = "tuer, collecter et interagir correspondent aux quêtes ayant au moins un objectif de ce type — une quête peut correspondre à plusieurs types. Les filtres de type nécessitent l'add-on Questie ou Quest Weaver."
  L["filter.help.example.7"]            = "type=donjon"
  L["filter.help.example.7.note"]       = "Afficher uniquement les quêtes de donjon (nécessite Questie ou Quest Weaver)"
  L["filter.help.example.8"]            = "type=tuer"
  L["filter.help.example.8.note"]       = "Afficher les quêtes avec au moins un objectif de type tuer"
  L["filter.help.example.9"]            = "type=journalière"
  L["filter.help.example.9.note"]       = "Afficher uniquement les quêtes journalières"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "donjon" Locales/frFR.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/frFR.lua
  git commit -m "feat(locale): add frFR filter translations"
  ```

---

### Task 3: esES (Spanish — Spain)

**Files:**
- Modify: `Locales/esES.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/esES.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "zona"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Nombre de zona (coincidencia parcial)"
  L["filter.key.title"]        = "título"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Título de misión (coincidencia parcial)"
  L["filter.key.chain"]        = "serie"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Título de serie (coincidencia parcial)"
  L["filter.key.player"]       = "jugador"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Nombre del miembro (solo pestañas Grupo/Compartido)"
  L["filter.key.level"]        = "nivel"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Nivel recomendado de la misión"
  L["filter.key.step"]         = "paso"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Número de paso en la serie"
  L["filter.key.group"]        = "grupo"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Requisito de grupo (sí, no, 2-5)"
  L["filter.key.type"]         = "tipo"
  L["filter.key.type.desc"]    = "Tipo de misión — serie, grupo, solitario, cronometrado, escolta, mazmorra, banda, élite, diaria, pvp, matar, recolectar, interactuar"
  L["filter.key.status"]       = "estado"
  L["filter.key.status.desc"]  = "Estado de la misión (completa, incompleta, fallida)"
  L["filter.key.tracked"]      = "seguido"
  L["filter.key.tracked.desc"] = "Seguido en el minimapa (sí, no; solo pestaña Yo)"
  L["filter.val.yes"]          = "sí"
  L["filter.val.no"]           = "no"
  L["filter.val.complete"]     = "completa"
  L["filter.val.incomplete"]   = "incompleta"
  L["filter.val.failed"]       = "fallida"
  L["filter.val.chain"]        = "serie"
  L["filter.val.group"]        = "grupo"
  L["filter.val.solo"]         = "solitario"
  L["filter.val.timed"]        = "cronometrado"
  L["filter.val.escort"]       = "escolta"
  L["filter.val.dungeon"]      = "mazmorra"
  L["filter.val.raid"]         = "banda"
  L["filter.val.elite"]        = "élite"
  L["filter.val.daily"]        = "diaria"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "matar"
  L["filter.val.gather"]       = "recolectar"
  L["filter.val.interact"]     = "interactuar"
  L["filter.err.UNKNOWN_KEY"]      = "clave de filtro desconocida '%s'"
  L["filter.err.INVALID_OPERATOR"] = "el operador '%s' no se puede usar con '%s'"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' requiere un campo numérico"
  L["filter.err.UNCLOSED_QUOTE"]   = "comilla sin cerrar en la expresión de filtro"
  L["filter.err.EMPTY_VALUE"]      = "falta el valor después de '%s'"
  L["filter.err.INVALID_NUMBER"]   = "se esperaba un número para '%s', se recibió '%s'"
  L["filter.err.RANGE_REVERSED"]   = "rango no válido: el mínimo (%s) debe ser <= máximo (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' no es un valor válido para '%s'"
  L["filter.err.label"]            = "Error de filtro: %s"
  L["filter.help.title"]                = "Sintaxis de filtros SQ"
  L["filter.help.intro"]                = "Escribe una expresión de filtro y pulsa Enter para aplicarla como etiqueta persistente. Cierra una etiqueta con [x]. Los filtros múltiples se combinan con Y."
  L["filter.help.section.syntax"]       = "Sintaxis"
  L["filter.help.section.keys"]         = "Claves admitidas"
  L["filter.help.section.examples"]     = "Ejemplos"
  L["filter.help.col.key"]              = "Clave"
  L["filter.help.col.aliases"]          = "Alias"
  L["filter.help.col.desc"]             = "Descripción"
  L["filter.help.example.1"]            = "nivel>=60"
  L["filter.help.example.1.note"]       = "Mostrar misiones de nivel 60 o más"
  L["filter.help.example.2"]            = "nivel=58..62"
  L["filter.help.example.2.note"]       = "Mostrar misiones en el rango de nivel 58-62"
  L["filter.help.example.3"]            = "zona=Elwynn|Minas"
  L["filter.help.example.3.note"]       = "Mostrar misiones en el Bosque de Elwynn O en las Minas de la Muerte"
  L["filter.help.example.4"]            = "estado=incompleta"
  L["filter.help.example.4.note"]       = "Mostrar solo misiones incompletas"
  L["filter.help.example.5"]            = "tipo=serie"
  L["filter.help.example.5.note"]       = "Mostrar solo misiones en serie"
  L["filter.help.example.6"]            = "zona=\"Península del Fuego Infernal\""
  L["filter.help.example.6.note"]       = "Valor entre comillas (úsalas cuando el valor contenga espacios)"
  L["filter.help.type.note"]            = "matar, recolectar e interactuar coinciden con misiones que tienen al menos un objetivo de ese tipo — las misiones pueden coincidir con varios tipos. Los filtros de tipo requieren el complemento Questie o Quest Weaver."
  L["filter.help.example.7"]            = "tipo=mazmorra"
  L["filter.help.example.7.note"]       = "Mostrar solo misiones de mazmorra (requiere Questie o Quest Weaver)"
  L["filter.help.example.8"]            = "tipo=matar"
  L["filter.help.example.8.note"]       = "Mostrar misiones con al menos un objetivo de matar"
  L["filter.help.example.9"]            = "tipo=diaria"
  L["filter.help.example.9.note"]       = "Mostrar solo misiones diarias"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "mazmorra" Locales/esES.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/esES.lua
  git commit -m "feat(locale): add esES filter translations"
  ```

---

### Task 4: esMX (Spanish — Latin America)

esMX is identical to esES — Latin American Spanish WoW uses the same quest terminology.

**Files:**
- Modify: `Locales/esMX.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/esMX.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Apply the exact same replacement as Task 3 (esES). Every string is identical.

- [ ] **Step 3: Verify**

  Run: `grep -c "mazmorra" Locales/esMX.lua`
  Expected: 2 or more

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/esMX.lua
  git commit -m "feat(locale): add esMX filter translations (identical to esES)"
  ```

---

### Task 5: zhCN (Simplified Chinese)

**Files:**
- Modify: `Locales/zhCN.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/zhCN.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "区域"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "区域名称（部分匹配）"
  L["filter.key.title"]        = "标题"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "任务标题（部分匹配）"
  L["filter.key.chain"]        = "任务链"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "任务链标题（部分匹配）"
  L["filter.key.player"]       = "玩家"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "队员名称（仅队伍/共享标签）"
  L["filter.key.level"]        = "等级"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "推荐任务等级"
  L["filter.key.step"]         = "步骤"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "任务链步骤编号"
  L["filter.key.group"]        = "组队"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "组队要求（是，否，2-5）"
  L["filter.key.type"]         = "类型"
  L["filter.key.type.desc"]    = "任务类型 — 任务链, 组队, 单人, 限时, 护送, 地下城, 团队副本, 精英, 日常, pvp, 击杀, 采集, 互动"
  L["filter.key.status"]       = "状态"
  L["filter.key.status.desc"]  = "任务状态（完成, 未完成, 失败）"
  L["filter.key.tracked"]      = "追踪"
  L["filter.key.tracked.desc"] = "在小地图上追踪（是, 否；仅我的标签）"
  L["filter.val.yes"]          = "是"
  L["filter.val.no"]           = "否"
  L["filter.val.complete"]     = "完成"
  L["filter.val.incomplete"]   = "未完成"
  L["filter.val.failed"]       = "失败"
  L["filter.val.chain"]        = "任务链"
  L["filter.val.group"]        = "组队"
  L["filter.val.solo"]         = "单人"
  L["filter.val.timed"]        = "限时"
  L["filter.val.escort"]       = "护送"
  L["filter.val.dungeon"]      = "地下城"
  L["filter.val.raid"]         = "团队副本"
  L["filter.val.elite"]        = "精英"
  L["filter.val.daily"]        = "日常"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "击杀"
  L["filter.val.gather"]       = "采集"
  L["filter.val.interact"]     = "互动"
  L["filter.err.UNKNOWN_KEY"]      = "未知的过滤键 '%s'"
  L["filter.err.INVALID_OPERATOR"] = "运算符 '%s' 不能与 '%s' 一起使用"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' 需要数字字段"
  L["filter.err.UNCLOSED_QUOTE"]   = "过滤表达式中存在未闭合的引号"
  L["filter.err.EMPTY_VALUE"]      = "'%s' 后缺少值"
  L["filter.err.INVALID_NUMBER"]   = "'%s' 需要数字，但收到 '%s'"
  L["filter.err.RANGE_REVERSED"]   = "无效范围：最小值 (%s) 必须 <= 最大值 (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' 不是 '%s' 的有效值"
  L["filter.err.label"]            = "过滤错误：%s"
  L["filter.help.title"]                = "SQ 过滤语法"
  L["filter.help.intro"]                = "输入过滤表达式并按 Enter 将其应用为持久标签。用 [x] 关闭标签。多个过滤条件以 AND 方式组合。"
  L["filter.help.section.syntax"]       = "语法"
  L["filter.help.section.keys"]         = "支持的键"
  L["filter.help.section.examples"]     = "示例"
  L["filter.help.col.key"]              = "键"
  L["filter.help.col.aliases"]          = "别名"
  L["filter.help.col.desc"]             = "描述"
  L["filter.help.example.1"]            = "等级>=60"
  L["filter.help.example.1.note"]       = "显示60级或以上的任务"
  L["filter.help.example.2"]            = "等级=58..62"
  L["filter.help.example.2.note"]       = "显示58-62级范围内的任务"
  L["filter.help.example.3"]            = "区域=艾尔文|死亡矿"
  L["filter.help.example.3.note"]       = "显示艾尔文森林或死亡矿井中的任务"
  L["filter.help.example.4"]            = "状态=未完成"
  L["filter.help.example.4.note"]       = "仅显示未完成的任务"
  L["filter.help.example.5"]            = "类型=任务链"
  L["filter.help.example.5.note"]       = "仅显示任务链中的任务"
  L["filter.help.example.6"]            = "区域=\"地狱火半岛\""
  L["filter.help.example.6.note"]       = "带引号的值（当值包含空格时使用）"
  L["filter.help.type.note"]            = "击杀、采集和互动匹配至少包含一个相应目标的任务——任务可以匹配多种类型。类型过滤器需要安装 Questie 或 Quest Weaver 插件。"
  L["filter.help.example.7"]            = "类型=地下城"
  L["filter.help.example.7.note"]       = "仅显示地下城任务（需要 Questie 或 Quest Weaver）"
  L["filter.help.example.8"]            = "类型=击杀"
  L["filter.help.example.8.note"]       = "显示至少有一个击杀目标的任务"
  L["filter.help.example.9"]            = "类型=日常"
  L["filter.help.example.9.note"]       = "仅显示日常任务"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "地下城" Locales/zhCN.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/zhCN.lua
  git commit -m "feat(locale): add zhCN filter translations"
  ```

---

### Task 6: zhTW (Traditional Chinese)

**Files:**
- Modify: `Locales/zhTW.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/zhTW.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "區域"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "區域名稱（部分匹配）"
  L["filter.key.title"]        = "標題"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "任務標題（部分匹配）"
  L["filter.key.chain"]        = "任務鏈"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "任務鏈標題（部分匹配）"
  L["filter.key.player"]       = "玩家"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "隊員名稱（僅隊伍/共享標籤）"
  L["filter.key.level"]        = "等級"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "推薦任務等級"
  L["filter.key.step"]         = "步驟"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "任務鏈步驟編號"
  L["filter.key.group"]        = "組隊"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "組隊要求（是，否，2-5）"
  L["filter.key.type"]         = "類型"
  L["filter.key.type.desc"]    = "任務類型 — 任務鏈, 組隊, 單人, 限時, 護送, 地下城, 團隊副本, 精英, 日常, pvp, 擊殺, 採集, 互動"
  L["filter.key.status"]       = "狀態"
  L["filter.key.status.desc"]  = "任務狀態（完成, 未完成, 失敗）"
  L["filter.key.tracked"]      = "追蹤"
  L["filter.key.tracked.desc"] = "在小地圖上追蹤（是, 否；僅我的標籤）"
  L["filter.val.yes"]          = "是"
  L["filter.val.no"]           = "否"
  L["filter.val.complete"]     = "完成"
  L["filter.val.incomplete"]   = "未完成"
  L["filter.val.failed"]       = "失敗"
  L["filter.val.chain"]        = "任務鏈"
  L["filter.val.group"]        = "組隊"
  L["filter.val.solo"]         = "單人"
  L["filter.val.timed"]        = "限時"
  L["filter.val.escort"]       = "護送"
  L["filter.val.dungeon"]      = "地下城"
  L["filter.val.raid"]         = "團隊副本"
  L["filter.val.elite"]        = "精英"
  L["filter.val.daily"]        = "日常"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "擊殺"
  L["filter.val.gather"]       = "採集"
  L["filter.val.interact"]     = "互動"
  L["filter.err.UNKNOWN_KEY"]      = "未知的過濾鍵 '%s'"
  L["filter.err.INVALID_OPERATOR"] = "運算符 '%s' 不能與 '%s' 一起使用"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' 需要數字字段"
  L["filter.err.UNCLOSED_QUOTE"]   = "過濾表達式中存在未閉合的引號"
  L["filter.err.EMPTY_VALUE"]      = "'%s' 後缺少值"
  L["filter.err.INVALID_NUMBER"]   = "'%s' 需要數字，但收到 '%s'"
  L["filter.err.RANGE_REVERSED"]   = "無效範圍：最小值 (%s) 必須 <= 最大值 (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' 不是 '%s' 的有效值"
  L["filter.err.label"]            = "過濾錯誤：%s"
  L["filter.help.title"]                = "SQ 過濾語法"
  L["filter.help.intro"]                = "輸入過濾表達式並按 Enter 將其應用為持久標籤。用 [x] 關閉標籤。多個過濾條件以 AND 方式組合。"
  L["filter.help.section.syntax"]       = "語法"
  L["filter.help.section.keys"]         = "支援的鍵"
  L["filter.help.section.examples"]     = "範例"
  L["filter.help.col.key"]              = "鍵"
  L["filter.help.col.aliases"]          = "別名"
  L["filter.help.col.desc"]             = "描述"
  L["filter.help.example.1"]            = "等級>=60"
  L["filter.help.example.1.note"]       = "顯示60級或以上的任務"
  L["filter.help.example.2"]            = "等級=58..62"
  L["filter.help.example.2.note"]       = "顯示58-62級範圍內的任務"
  L["filter.help.example.3"]            = "區域=艾爾文|死亡礦"
  L["filter.help.example.3.note"]       = "顯示艾爾文森林或死亡礦井中的任務"
  L["filter.help.example.4"]            = "狀態=未完成"
  L["filter.help.example.4.note"]       = "僅顯示未完成的任務"
  L["filter.help.example.5"]            = "類型=任務鏈"
  L["filter.help.example.5.note"]       = "僅顯示任務鏈中的任務"
  L["filter.help.example.6"]            = "區域=\"地獄火半島\""
  L["filter.help.example.6.note"]       = "帶引號的值（當值包含空格時使用）"
  L["filter.help.type.note"]            = "擊殺、採集和互動匹配至少包含一個相應目標的任務——任務可以匹配多種類型。類型過濾器需要安裝 Questie 或 Quest Weaver 插件。"
  L["filter.help.example.7"]            = "類型=地下城"
  L["filter.help.example.7.note"]       = "僅顯示地下城任務（需要 Questie 或 Quest Weaver）"
  L["filter.help.example.8"]            = "類型=擊殺"
  L["filter.help.example.8.note"]       = "顯示至少有一個擊殺目標的任務"
  L["filter.help.example.9"]            = "類型=日常"
  L["filter.help.example.9.note"]       = "僅顯示日常任務"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "地下城" Locales/zhTW.lua`
  Expected: 2 or more

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/zhTW.lua
  git commit -m "feat(locale): add zhTW filter translations"
  ```

---

### Task 7: ptBR (Brazilian Portuguese)

**Files:**
- Modify: `Locales/ptBR.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/ptBR.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "zona"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Nome da zona (correspondência parcial)"
  L["filter.key.title"]        = "título"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Título da missão (correspondência parcial)"
  L["filter.key.chain"]        = "série"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Título da série (correspondência parcial)"
  L["filter.key.player"]       = "jogador"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Nome do membro (apenas abas Grupo/Compartilhado)"
  L["filter.key.level"]        = "nível"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Nível recomendado da missão"
  L["filter.key.step"]         = "passo"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Número do passo na série"
  L["filter.key.group"]        = "grupo"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Requisito de grupo (sim, não, 2-5)"
  L["filter.key.type"]         = "tipo"
  L["filter.key.type.desc"]    = "Tipo de missão — série, grupo, solo, cronometrado, escolta, masmorra, raide, elite, diária, pvp, matar, coletar, interagir"
  L["filter.key.status"]       = "estado"
  L["filter.key.status.desc"]  = "Estado da missão (completa, incompleta, falhou)"
  L["filter.key.tracked"]      = "rastreado"
  L["filter.key.tracked.desc"] = "Rastreado no minimapa (sim, não; apenas aba Meu)"
  L["filter.val.yes"]          = "sim"
  L["filter.val.no"]           = "não"
  L["filter.val.complete"]     = "completa"
  L["filter.val.incomplete"]   = "incompleta"
  L["filter.val.failed"]       = "falhou"
  L["filter.val.chain"]        = "série"
  L["filter.val.group"]        = "grupo"
  L["filter.val.solo"]         = "solo"
  L["filter.val.timed"]        = "cronometrado"
  L["filter.val.escort"]       = "escolta"
  L["filter.val.dungeon"]      = "masmorra"
  L["filter.val.raid"]         = "raide"
  L["filter.val.elite"]        = "elite"
  L["filter.val.daily"]        = "diária"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "matar"
  L["filter.val.gather"]       = "coletar"
  L["filter.val.interact"]     = "interagir"
  L["filter.err.UNKNOWN_KEY"]      = "chave de filtro desconhecida '%s'"
  L["filter.err.INVALID_OPERATOR"] = "o operador '%s' não pode ser usado com '%s'"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' requer um campo numérico"
  L["filter.err.UNCLOSED_QUOTE"]   = "aspas não fechadas na expressão de filtro"
  L["filter.err.EMPTY_VALUE"]      = "valor ausente após '%s'"
  L["filter.err.INVALID_NUMBER"]   = "esperava um número para '%s', recebeu '%s'"
  L["filter.err.RANGE_REVERSED"]   = "intervalo inválido: o mínimo (%s) deve ser <= máximo (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' não é um valor válido para '%s'"
  L["filter.err.label"]            = "Erro de filtro: %s"
  L["filter.help.title"]                = "Sintaxe de filtros SQ"
  L["filter.help.intro"]                = "Digite uma expressão de filtro e pressione Enter para aplicá-la como etiqueta persistente. Feche uma etiqueta com [x]. Múltiplos filtros se combinam com E."
  L["filter.help.section.syntax"]       = "Sintaxe"
  L["filter.help.section.keys"]         = "Chaves suportadas"
  L["filter.help.section.examples"]     = "Exemplos"
  L["filter.help.col.key"]              = "Chave"
  L["filter.help.col.aliases"]          = "Apelidos"
  L["filter.help.col.desc"]             = "Descrição"
  L["filter.help.example.1"]            = "nível>=60"
  L["filter.help.example.1.note"]       = "Mostrar missões de nível 60 ou superior"
  L["filter.help.example.2"]            = "nível=58..62"
  L["filter.help.example.2.note"]       = "Mostrar missões no intervalo de nível 58-62"
  L["filter.help.example.3"]            = "zona=Elwynn|Minas"
  L["filter.help.example.3.note"]       = "Mostrar missões na Floresta de Elwynn OU nas Minas da Morte"
  L["filter.help.example.4"]            = "estado=incompleta"
  L["filter.help.example.4.note"]       = "Mostrar apenas missões incompletas"
  L["filter.help.example.5"]            = "tipo=série"
  L["filter.help.example.5.note"]       = "Mostrar apenas missões em série"
  L["filter.help.example.6"]            = "zona=\"Península do Fogo Infernal\""
  L["filter.help.example.6.note"]       = "Valor entre aspas (use quando o valor contiver espaços)"
  L["filter.help.type.note"]            = "matar, coletar e interagir correspondem a missões com pelo menos um objetivo desse tipo — missões podem corresponder a vários tipos. Os filtros de tipo requerem o add-on Questie ou Quest Weaver."
  L["filter.help.example.7"]            = "tipo=masmorra"
  L["filter.help.example.7.note"]       = "Mostrar apenas missões de masmorra (requer Questie ou Quest Weaver)"
  L["filter.help.example.8"]            = "tipo=matar"
  L["filter.help.example.8.note"]       = "Mostrar missões com pelo menos um objetivo de matar"
  L["filter.help.example.9"]            = "tipo=diária"
  L["filter.help.example.9.note"]       = "Mostrar apenas missões diárias"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "masmorra" Locales/ptBR.lua`
  Expected: 2 or more

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/ptBR.lua
  git commit -m "feat(locale): add ptBR filter translations"
  ```

---

### Task 8: itIT (Italian)

**Files:**
- Modify: `Locales/itIT.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/itIT.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "zona"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Nome della zona (corrispondenza parziale)"
  L["filter.key.title"]        = "titolo"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Titolo della missione (corrispondenza parziale)"
  L["filter.key.chain"]        = "serie"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Titolo della serie (corrispondenza parziale)"
  L["filter.key.player"]       = "giocatore"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Nome del membro (solo schede Gruppo/Condiviso)"
  L["filter.key.level"]        = "livello"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Livello consigliato della missione"
  L["filter.key.step"]         = "passo"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Numero del passo nella serie"
  L["filter.key.group"]        = "gruppo"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Requisito di gruppo (sì, no, 2-5)"
  L["filter.key.type"]         = "tipo"
  L["filter.key.type.desc"]    = "Tipo di missione — serie, gruppo, solo, a tempo, scorta, dungeon, incursione, elite, giornaliera, pvp, uccidere, raccogliere, interagire"
  L["filter.key.status"]       = "stato"
  L["filter.key.status.desc"]  = "Stato della missione (completata, incompleta, fallita)"
  L["filter.key.tracked"]      = "monitorato"
  L["filter.key.tracked.desc"] = "Monitorato sulla minimappa (sì, no; solo scheda Mio)"
  L["filter.val.yes"]          = "sì"
  L["filter.val.no"]           = "no"
  L["filter.val.complete"]     = "completata"
  L["filter.val.incomplete"]   = "incompleta"
  L["filter.val.failed"]       = "fallita"
  L["filter.val.chain"]        = "serie"
  L["filter.val.group"]        = "gruppo"
  L["filter.val.solo"]         = "solo"
  L["filter.val.timed"]        = "a tempo"
  L["filter.val.escort"]       = "scorta"
  L["filter.val.dungeon"]      = "dungeon"
  L["filter.val.raid"]         = "incursione"
  L["filter.val.elite"]        = "elite"
  L["filter.val.daily"]        = "giornaliera"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "uccidere"
  L["filter.val.gather"]       = "raccogliere"
  L["filter.val.interact"]     = "interagire"
  L["filter.err.UNKNOWN_KEY"]      = "chiave filtro sconosciuta '%s'"
  L["filter.err.INVALID_OPERATOR"] = "l'operatore '%s' non può essere usato con '%s'"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' richiede un campo numerico"
  L["filter.err.UNCLOSED_QUOTE"]   = "virgolette non chiuse nell'espressione del filtro"
  L["filter.err.EMPTY_VALUE"]      = "valore mancante dopo '%s'"
  L["filter.err.INVALID_NUMBER"]   = "era atteso un numero per '%s', ricevuto '%s'"
  L["filter.err.RANGE_REVERSED"]   = "intervallo non valido: il min (%s) deve essere <= max (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' non è un valore valido per '%s'"
  L["filter.err.label"]            = "Errore filtro: %s"
  L["filter.help.title"]                = "Sintassi filtri SQ"
  L["filter.help.intro"]                = "Digita un'espressione di filtro e premi Invio per applicarla come etichetta persistente. Chiudi un'etichetta con [x]. Più filtri vengono combinati con E."
  L["filter.help.section.syntax"]       = "Sintassi"
  L["filter.help.section.keys"]         = "Chiavi supportate"
  L["filter.help.section.examples"]     = "Esempi"
  L["filter.help.col.key"]              = "Chiave"
  L["filter.help.col.aliases"]          = "Alias"
  L["filter.help.col.desc"]             = "Descrizione"
  L["filter.help.example.1"]            = "livello>=60"
  L["filter.help.example.1.note"]       = "Mostra missioni di livello 60 o superiore"
  L["filter.help.example.2"]            = "livello=58..62"
  L["filter.help.example.2.note"]       = "Mostra missioni nel range di livello 58-62"
  L["filter.help.example.3"]            = "zona=Elwynn|Miniere"
  L["filter.help.example.3.note"]       = "Mostra missioni nella Foresta di Elwynn O nelle Miniere della Morte"
  L["filter.help.example.4"]            = "stato=incompleta"
  L["filter.help.example.4.note"]       = "Mostra solo missioni incomplete"
  L["filter.help.example.5"]            = "tipo=serie"
  L["filter.help.example.5.note"]       = "Mostra solo missioni in serie"
  L["filter.help.example.6"]            = "zona=\"Penisola del Fuoco Infernale\""
  L["filter.help.example.6.note"]       = "Valore tra virgolette (da usare quando il valore contiene spazi)"
  L["filter.help.type.note"]            = "uccidere, raccogliere e interagire corrispondono alle missioni con almeno un obiettivo di quel tipo — le missioni possono corrispondere a più tipi. I filtri di tipo richiedono l'add-on Questie o Quest Weaver."
  L["filter.help.example.7"]            = "tipo=dungeon"
  L["filter.help.example.7.note"]       = "Mostra solo missioni dungeon (richiede Questie o Quest Weaver)"
  L["filter.help.example.8"]            = "tipo=uccidere"
  L["filter.help.example.8.note"]       = "Mostra missioni con almeno un obiettivo di uccidere"
  L["filter.help.example.9"]            = "tipo=giornaliera"
  L["filter.help.example.9.note"]       = "Mostra solo missioni giornaliere"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "incursione" Locales/itIT.lua`
  Expected: 2 or more (val.raid + type desc)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/itIT.lua
  git commit -m "feat(locale): add itIT filter translations"
  ```

---

### Task 9: koKR (Korean)

**Files:**
- Modify: `Locales/koKR.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/koKR.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "구역"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "구역 이름 (부분 일치)"
  L["filter.key.title"]        = "제목"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "퀘스트 제목 (부분 일치)"
  L["filter.key.chain"]        = "연쇄"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "연쇄 제목 (부분 일치)"
  L["filter.key.player"]       = "플레이어"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "파티원 이름 (파티/공유 탭 전용)"
  L["filter.key.level"]        = "레벨"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "권장 퀘스트 레벨"
  L["filter.key.step"]         = "단계"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "연쇄 단계 번호"
  L["filter.key.group"]        = "그룹"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "그룹 요건 (예, 아니오, 2-5)"
  L["filter.key.type"]         = "유형"
  L["filter.key.type.desc"]    = "퀘스트 유형 — 연쇄, 그룹, 솔로, 시간제한, 호위, 던전, 공격대, 정예, 일일, pvp, 처치, 수집, 상호작용"
  L["filter.key.status"]       = "상태"
  L["filter.key.status.desc"]  = "퀘스트 상태 (완료, 미완료, 실패)"
  L["filter.key.tracked"]      = "추적중"
  L["filter.key.tracked.desc"] = "미니맵 추적 중 (예, 아니오; 내 탭 전용)"
  L["filter.val.yes"]          = "예"
  L["filter.val.no"]           = "아니오"
  L["filter.val.complete"]     = "완료"
  L["filter.val.incomplete"]   = "미완료"
  L["filter.val.failed"]       = "실패"
  L["filter.val.chain"]        = "연쇄"
  L["filter.val.group"]        = "그룹"
  L["filter.val.solo"]         = "솔로"
  L["filter.val.timed"]        = "시간제한"
  L["filter.val.escort"]       = "호위"
  L["filter.val.dungeon"]      = "던전"
  L["filter.val.raid"]         = "공격대"
  L["filter.val.elite"]        = "정예"
  L["filter.val.daily"]        = "일일"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "처치"
  L["filter.val.gather"]       = "수집"
  L["filter.val.interact"]     = "상호작용"
  L["filter.err.UNKNOWN_KEY"]      = "알 수 없는 필터 키 '%s'"
  L["filter.err.INVALID_OPERATOR"] = "연산자 '%s'은(는) '%s'에 사용할 수 없습니다"
  L["filter.err.TYPE_MISMATCH"]    = "'%s'은(는) 숫자 필드가 필요합니다"
  L["filter.err.UNCLOSED_QUOTE"]   = "필터 표현식에 닫히지 않은 따옴표가 있습니다"
  L["filter.err.EMPTY_VALUE"]      = "'%s' 다음에 값이 없습니다"
  L["filter.err.INVALID_NUMBER"]   = "'%s'에 숫자가 필요하지만 '%s'을(를) 받았습니다"
  L["filter.err.RANGE_REVERSED"]   = "잘못된 범위: 최솟값 (%s)은 최댓값 (%s) 이하여야 합니다"
  L["filter.err.INVALID_ENUM"]     = "'%s'은(는) '%s'에 유효한 값이 아닙니다"
  L["filter.err.label"]            = "필터 오류: %s"
  L["filter.help.title"]                = "SQ 필터 구문"
  L["filter.help.intro"]                = "필터 표현식을 입력하고 Enter를 눌러 고정 레이블로 적용합니다. [x]로 레이블을 닫습니다. 여러 필터는 AND로 결합됩니다."
  L["filter.help.section.syntax"]       = "구문"
  L["filter.help.section.keys"]         = "지원되는 키"
  L["filter.help.section.examples"]     = "예시"
  L["filter.help.col.key"]              = "키"
  L["filter.help.col.aliases"]          = "별칭"
  L["filter.help.col.desc"]             = "설명"
  L["filter.help.example.1"]            = "레벨>=60"
  L["filter.help.example.1.note"]       = "레벨 60 이상의 퀘스트 표시"
  L["filter.help.example.2"]            = "레벨=58..62"
  L["filter.help.example.2.note"]       = "레벨 58-62 범위의 퀘스트 표시"
  L["filter.help.example.3"]            = "구역=엘윈|죽음의"
  L["filter.help.example.3.note"]       = "엘윈 숲 또는 죽음의 광산의 퀘스트 표시"
  L["filter.help.example.4"]            = "상태=미완료"
  L["filter.help.example.4.note"]       = "미완료 퀘스트만 표시"
  L["filter.help.example.5"]            = "유형=연쇄"
  L["filter.help.example.5.note"]       = "연쇄 퀘스트만 표시"
  L["filter.help.example.6"]            = "구역=\"지옥불 반도\""
  L["filter.help.example.6.note"]       = "따옴표로 묶인 값 (값에 공백이 있을 때 사용)"
  L["filter.help.type.note"]            = "처치, 수집, 상호작용은 해당 종류의 목표가 하나 이상 있는 퀘스트와 일치합니다 — 퀘스트는 여러 유형에 해당할 수 있습니다. 유형 필터는 Questie 또는 Quest Weaver 애드온이 필요합니다."
  L["filter.help.example.7"]            = "유형=던전"
  L["filter.help.example.7.note"]       = "던전 퀘스트만 표시 (Questie 또는 Quest Weaver 필요)"
  L["filter.help.example.8"]            = "유형=처치"
  L["filter.help.example.8.note"]       = "처치 목표가 하나 이상 있는 퀘스트 표시"
  L["filter.help.example.9"]            = "유형=일일"
  L["filter.help.example.9.note"]       = "일일 퀘스트만 표시"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "던전" Locales/koKR.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/koKR.lua
  git commit -m "feat(locale): add koKR filter translations"
  ```

---

### Task 10: ruRU (Russian)

**Files:**
- Modify: `Locales/ruRU.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/ruRU.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "зона"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "Название зоны (поиск по подстроке)"
  L["filter.key.title"]        = "название"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "Название задания (поиск по подстроке)"
  L["filter.key.chain"]        = "цепочка"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "Название цепочки (поиск по подстроке)"
  L["filter.key.player"]       = "игрок"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "Имя участника группы (только вкладки Группа/Общее)"
  L["filter.key.level"]        = "уровень"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "Рекомендуемый уровень задания"
  L["filter.key.step"]         = "шаг"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "Номер шага в цепочке"
  L["filter.key.group"]        = "группа"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "Требование группы (да, нет, 2-5)"
  L["filter.key.type"]         = "тип"
  L["filter.key.type.desc"]    = "Тип задания — цепочка, группа, соло, на время, сопровождение, подземелье, рейд, элитный, ежедневное, pvp, убийство, собрать, взаимодействие"
  L["filter.key.status"]       = "статус"
  L["filter.key.status.desc"]  = "Статус задания (выполнено, не выполнено, провалено)"
  L["filter.key.tracked"]      = "отслеживается"
  L["filter.key.tracked.desc"] = "Отслеживается на миникарте (да, нет; только вкладка Мои)"
  L["filter.val.yes"]          = "да"
  L["filter.val.no"]           = "нет"
  L["filter.val.complete"]     = "выполнено"
  L["filter.val.incomplete"]   = "не выполнено"
  L["filter.val.failed"]       = "провалено"
  L["filter.val.chain"]        = "цепочка"
  L["filter.val.group"]        = "группа"
  L["filter.val.solo"]         = "соло"
  L["filter.val.timed"]        = "на время"
  L["filter.val.escort"]       = "сопровождение"
  L["filter.val.dungeon"]      = "подземелье"
  L["filter.val.raid"]         = "рейд"
  L["filter.val.elite"]        = "элитный"
  L["filter.val.daily"]        = "ежедневное"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "убийство"
  L["filter.val.gather"]       = "собрать"
  L["filter.val.interact"]     = "взаимодействие"
  L["filter.err.UNKNOWN_KEY"]      = "неизвестный ключ фильтра '%s'"
  L["filter.err.INVALID_OPERATOR"] = "оператор '%s' нельзя использовать с '%s'"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' требует числового поля"
  L["filter.err.UNCLOSED_QUOTE"]   = "незакрытая кавычка в выражении фильтра"
  L["filter.err.EMPTY_VALUE"]      = "отсутствует значение после '%s'"
  L["filter.err.INVALID_NUMBER"]   = "ожидалось число для '%s', получено '%s'"
  L["filter.err.RANGE_REVERSED"]   = "неверный диапазон: мин (%s) должен быть <= макс (%s)"
  L["filter.err.INVALID_ENUM"]     = "'%s' не является допустимым значением для '%s'"
  L["filter.err.label"]            = "Ошибка фильтра: %s"
  L["filter.help.title"]                = "Синтаксис фильтров SQ"
  L["filter.help.intro"]                = "Введите выражение фильтра и нажмите Enter, чтобы применить его как постоянную метку. Закройте метку кнопкой [x]. Несколько фильтров объединяются по И."
  L["filter.help.section.syntax"]       = "Синтаксис"
  L["filter.help.section.keys"]         = "Поддерживаемые ключи"
  L["filter.help.section.examples"]     = "Примеры"
  L["filter.help.col.key"]              = "Ключ"
  L["filter.help.col.aliases"]          = "Псевдонимы"
  L["filter.help.col.desc"]             = "Описание"
  L["filter.help.example.1"]            = "уровень>=60"
  L["filter.help.example.1.note"]       = "Показать задания для уровня 60 и выше"
  L["filter.help.example.2"]            = "уровень=58..62"
  L["filter.help.example.2.note"]       = "Показать задания в диапазоне уровней 58-62"
  L["filter.help.example.3"]            = "зона=Элвинн|Мёртвые"
  L["filter.help.example.3.note"]       = "Показать задания в Лесу Элвинн ИЛИ Мёртвых копях"
  L["filter.help.example.4"]            = "статус=не выполнено"
  L["filter.help.example.4.note"]       = "Показать только невыполненные задания"
  L["filter.help.example.5"]            = "тип=цепочка"
  L["filter.help.example.5.note"]       = "Показать только задания-цепочки"
  L["filter.help.example.6"]            = "зона=\"Полуостров Адского Пламени\""
  L["filter.help.example.6.note"]       = "Значение в кавычках (используйте, если значение содержит пробелы)"
  L["filter.help.type.note"]            = "убийство, собрать и взаимодействие совпадают с заданиями, имеющими хотя бы одну цель такого рода — задания могут соответствовать нескольким типам. Фильтры типов требуют установки аддона Questie или Quest Weaver."
  L["filter.help.example.7"]            = "тип=подземелье"
  L["filter.help.example.7.note"]       = "Показать только задания подземелья (требуется Questie или Quest Weaver)"
  L["filter.help.example.8"]            = "тип=убийство"
  L["filter.help.example.8.note"]       = "Показать задания хотя бы с одной целью убийства"
  L["filter.help.example.9"]            = "тип=ежедневное"
  L["filter.help.example.9.note"]       = "Показать только ежедневные задания"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "подземелье" Locales/ruRU.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/ruRU.lua
  git commit -m "feat(locale): add ruRU filter translations"
  ```

---

### Task 11: jaJP (Japanese)

**Files:**
- Modify: `Locales/jaJP.lua`

- [ ] **Step 1: Read the current file to confirm the block location**

  Read `Locales/jaJP.lua` and find the `-- Advanced filter language (Feature #18)` block.

- [ ] **Step 2: Replace the filter block**

  Replace the entire block with:

  ```lua
  -- Advanced filter language (Feature #18)
  L["filter.key.zone"]         = "ゾーン"
  L["filter.key.zone.z"]=true
  L["filter.key.zone.desc"]    = "ゾーン名（部分一致）"
  L["filter.key.title"]        = "タイトル"
  L["filter.key.title.t"]=true
  L["filter.key.title.desc"]   = "クエストタイトル（部分一致）"
  L["filter.key.chain"]        = "シリーズ"
  L["filter.key.chain.c"]=true
  L["filter.key.chain.desc"]   = "シリーズタイトル（部分一致）"
  L["filter.key.player"]       = "プレイヤー"
  L["filter.key.player.p"]=true
  L["filter.key.player.desc"]  = "パーティメンバー名（パーティ/共有タブのみ）"
  L["filter.key.level"]        = "レベル"
  L["filter.key.level.lvl"]=true L["filter.key.level.l"]=true
  L["filter.key.level.desc"]   = "推奨クエストレベル"
  L["filter.key.step"]         = "ステップ"
  L["filter.key.step.s"]=true
  L["filter.key.step.desc"]    = "シリーズのステップ番号"
  L["filter.key.group"]        = "グループ"
  L["filter.key.group.g"]=true
  L["filter.key.group.desc"]   = "グループ要件（はい, いいえ, 2-5）"
  L["filter.key.type"]         = "タイプ"
  L["filter.key.type.desc"]    = "クエストタイプ — シリーズ, グループ, ソロ, 時間制限, エスコート, ダンジョン, レイド, エリート, デイリー, pvp, 討伐, 採集, インタラクト"
  L["filter.key.status"]       = "ステータス"
  L["filter.key.status.desc"]  = "クエストステータス（完了, 未完了, 失敗）"
  L["filter.key.tracked"]      = "追跡中"
  L["filter.key.tracked.desc"] = "ミニマップで追跡中（はい, いいえ；マイタブのみ）"
  L["filter.val.yes"]          = "はい"
  L["filter.val.no"]           = "いいえ"
  L["filter.val.complete"]     = "完了"
  L["filter.val.incomplete"]   = "未完了"
  L["filter.val.failed"]       = "失敗"
  L["filter.val.chain"]        = "シリーズ"
  L["filter.val.group"]        = "グループ"
  L["filter.val.solo"]         = "ソロ"
  L["filter.val.timed"]        = "時間制限"
  L["filter.val.escort"]       = "エスコート"
  L["filter.val.dungeon"]      = "ダンジョン"
  L["filter.val.raid"]         = "レイド"
  L["filter.val.elite"]        = "エリート"
  L["filter.val.daily"]        = "デイリー"
  L["filter.val.pvp"]          = "pvp"
  L["filter.val.kill"]         = "討伐"
  L["filter.val.gather"]       = "採集"
  L["filter.val.interact"]     = "インタラクト"
  L["filter.err.UNKNOWN_KEY"]      = "不明なフィルターキー '%s'"
  L["filter.err.INVALID_OPERATOR"] = "演算子 '%s' は '%s' には使用できません"
  L["filter.err.TYPE_MISMATCH"]    = "'%s' には数値フィールドが必要です"
  L["filter.err.UNCLOSED_QUOTE"]   = "フィルター式に閉じられていない引用符があります"
  L["filter.err.EMPTY_VALUE"]      = "'%s' の後に値がありません"
  L["filter.err.INVALID_NUMBER"]   = "'%s' には数値が必要ですが、'%s' を受け取りました"
  L["filter.err.RANGE_REVERSED"]   = "無効な範囲：最小値 (%s) は最大値 (%s) 以下である必要があります"
  L["filter.err.INVALID_ENUM"]     = "'%s' は '%s' の有効な値ではありません"
  L["filter.err.label"]            = "フィルターエラー：%s"
  L["filter.help.title"]                = "SQ フィルター構文"
  L["filter.help.intro"]                = "フィルター式を入力してEnterを押すと、固定ラベルとして適用されます。[x]でラベルを閉じます。複数のフィルターはANDで結合されます。"
  L["filter.help.section.syntax"]       = "構文"
  L["filter.help.section.keys"]         = "サポートされているキー"
  L["filter.help.section.examples"]     = "例"
  L["filter.help.col.key"]              = "キー"
  L["filter.help.col.aliases"]          = "エイリアス"
  L["filter.help.col.desc"]             = "説明"
  L["filter.help.example.1"]            = "レベル>=60"
  L["filter.help.example.1.note"]       = "レベル60以上のクエストを表示"
  L["filter.help.example.2"]            = "レベル=58..62"
  L["filter.help.example.2.note"]       = "レベル58-62範囲のクエストを表示"
  L["filter.help.example.3"]            = "ゾーン=エルウィン|デッドマインズ"
  L["filter.help.example.3.note"]       = "エルウィンの森またはデッドマインズのクエストを表示"
  L["filter.help.example.4"]            = "ステータス=未完了"
  L["filter.help.example.4.note"]       = "未完了のクエストのみ表示"
  L["filter.help.example.5"]            = "タイプ=シリーズ"
  L["filter.help.example.5.note"]       = "シリーズクエストのみ表示"
  L["filter.help.example.6"]            = "ゾーン=\"地獄火の半島\""
  L["filter.help.example.6.note"]       = "引用符付きの値（値にスペースが含まれる場合に使用）"
  L["filter.help.type.note"]            = "討伐、採集、インタラクトは、その種類の目標が少なくとも1つあるクエストに一致します — クエストは複数のタイプに一致できます。タイプフィルターには Questie または Quest Weaver アドオンが必要です。"
  L["filter.help.example.7"]            = "タイプ=ダンジョン"
  L["filter.help.example.7.note"]       = "ダンジョンクエストのみ表示（Questie または Quest Weaver が必要）"
  L["filter.help.example.8"]            = "タイプ=討伐"
  L["filter.help.example.8.note"]       = "討伐目標が少なくとも1つあるクエストを表示"
  L["filter.help.example.9"]            = "タイプ=デイリー"
  L["filter.help.example.9.note"]       = "デイリークエストのみ表示"
  ```

- [ ] **Step 3: Verify**

  Run: `grep -c "ダンジョン" Locales/jaJP.lua`
  Expected: 2 or more (val.dungeon + example 7)

- [ ] **Step 4: Commit**

  ```bash
  git add Locales/jaJP.lua
  git commit -m "feat(locale): add jaJP filter translations"
  ```

---

### Task 12: Version bump and CLAUDE.md

**Files:**
- Modify: `SocialQuest.toc`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Bump version in SocialQuest.toc**

  In `SocialQuest.toc`, change:
  ```
  ## Version: 2.12.29
  ```
  to:
  ```
  ## Version: 2.12.30
  ```

- [ ] **Step 2: Add version history entry to CLAUDE.md**

  In `CLAUDE.md`, in the Version History section, add the following entry immediately before the `### Version 2.12.29` heading:

  ```markdown
  ### Version 2.12.30 (March 2026 — AdvancedFilters branch)
  - Feature: Full filter localization for 11 non-enUS locales (deDE, frFR, esES, esMX, zhCN, zhTW, ptBR, itIT, koKR, ruRU, jaJP). All `filter.*` keys previously falling back to enUS (`= true`) are now replaced with natural, game-appropriate translated strings — key names players type, enum values, key descriptions, error messages, and help window text. Single-letter aliases remain `= true` (English letters). WoW's own in-game terminology is used where applicable (e.g., German Verlies/Schlachtzug, French Donjon, Spanish Mazmorra/Banda, Korean 던전/공격대). esMX is identical to esES.

  ```

- [ ] **Step 3: Verify**

  Run: `grep "2.12.30" SocialQuest.toc`
  Expected: `## Version: 2.12.30`

- [ ] **Step 4: Commit**

  ```bash
  git add SocialQuest.toc CLAUDE.md
  git commit -m "chore: bump version to 2.12.30 for filter localization feature"
  ```
