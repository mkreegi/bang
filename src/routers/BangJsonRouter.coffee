###
Bang, frontend JSON workspace, a chrome extension

Copyright (c) 2015, Groupon, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

Neither the name of GROUPON nor the names of its contributors may be
used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

define [
  "jquery"
  "underscore"
  "backbone"
  "URI"
  "d3"
  "mustache"
  "app/templates"
  "app/BangJsonPathFragment"
  "app/BangJsonPath"
  "app/BangJsonView"
  "app/BangQueryPanelView"
  "app/BangRequestPanelView"
], ($, _, Backbone, URI, d3, Mustache, templates, BangJsonPathFragment, BangJsonPath, BangJsonView, BangQueryPanelView, BangRequestPanelView)->

  # Models
  jsonPath = null

  # Views
  bangJsonView = null
  bangQueryPanelView = null
  bangRequestPanelView = null

  class BangJsonRouter extends Backbone.Router
    initialize: (options)->
      @bang = options.bang
      console.info "Bang (v#{chrome.runtime.getManifest().version}) will make your life with JSON easier!"
      chrome.runtime.sendMessage {stage: "load"}
      toggler = d3.select("body").append("div").attr("id", "showBang").style({
        position: "fixed"
        top: 40
        right: 40
        display: "none"
      }).append("button").attr("class", "btn btn-default btn-lg").text("Open Bang Workspace")
      wrapper = d3.select("body").append("div").attr("id", "bangWrapper").style({
        position: "absolute"
        height: window.innerHeight
        width: "100%"
        top: "0px"
        left: "0px"
        right: "0px"
        bottom: "0px"
        "z-index": 999
      })
      fade = wrapper.append("div").attr("id", "bangFade").style({
        position: "fixed"
        height: window.innerHeight
        width: "100%"
        top: 0
        left: 0
        right: 0
        bottom: 0
        "z-index": 999
        opacity: 0.6
        "background-color": "#777777"
      })
      $(window).resize ->
        wrapper.style "height", window.innerHeight
        fade.style "height", window.innerHeight
      root = wrapper.append("div").attr("class", "container-fluid").attr("id", "bang").style({
        position: "absolute"
        "padding-top": 60
        "padding-bottom": 130
        left: "3%"
        width: "94%"
        "z-index": 1000
      })
      @renderNavbar root.append("div").attr("class", "navbar navbar-default navbar-fixed-top")
      queryRow = root.append("div").attr("class", "row")
      responseRow = root.append("div").attr("class", "row")
      jsonPath = new BangJsonPath [new BangJsonPathFragment({fragment: if @bang instanceof Array then "bang[]" else "bang"})], {baseExpression: "bang"}
      jsonPath.bang = @bang
      bangJsonView = new BangJsonView {
        model: jsonPath
        el: queryRow.append("div").attr("class", "col-lg-12 col-md-12 col-sm-12 col-xs-12").append("div").attr("class", "panel panel-default panel-primary").attr("id", "navigatorPanel").node()
      }
      bangJsonView.render()
      bangQueryPanelView = new BangQueryPanelView {
        el: root.append("div").attr("class", "navbar navbar-default navbar-fixed-bottom").attr("id", "queryPanel").node()
      }
      bangQueryPanelView.render()
      bangRequestPanelView = new BangRequestPanelView {
        el: responseRow.append("div").attr("class", "col-lg-12 col-md-12 col-sm-12 col-xs-12").append("div").attr("class", "panel panel-success").attr("id", "requestPanel").node()
        model: new URI(document.location.href)
      }
      bangRequestPanelView.render()
      @importCss root
      # Bind listeners and click events
      @listenTo jsonPath, "change:path", ->
        chrome.runtime.sendMessage {stage: "browse"}
        {error, result} = jsonPath.getResult()
        if error
          bangJsonView.showErrorMessage error
        else
          bangQueryPanelView.updateQuery jsonPath.getQuery(null, true)
          jsonPath.trigger "change:result", result
      @listenTo bangQueryPanelView, "change:query", (query)->
        chrome.runtime.sendMessage {stage: "query"}
        bangJsonView.clear()
        {error, result} = jsonPath.getResult(query)
        if error
          bangJsonView.showErrorMessage error
        else
          bangJsonView.model.baseExpression = query
          jsonPath.queryResult = result
          if result instanceof Array
            jsonPath.set [new BangJsonPathFragment {fragment: "queryResult[]"}]
          else
            jsonPath.set [new BangJsonPathFragment {fragment: "queryResult"}]
          jsonPath.trigger "change:result", result
      @listenTo bangQueryPanelView, "reset:query", ->
        jsonPath.baseExpression = "bang"
        jsonPath.set {fragment: if @bang instanceof Array then "bang[]" else "bang"}
        jsonPath.trigger "change:path"
      $("#dismissBang").click (ev)->
        ev.preventDefault()
        chrome.runtime.sendMessage {stage: "dismiss"}
        $("#bangWrapper").hide()
        $("#showBang").show()
      $("#showBang button").click ->
        chrome.runtime.sendMessage {stage: "activate"}
        $("#bangWrapper").show()
        $("#showBang").hide()
      jsonPath.trigger "change:path"

    renderNavbar: (navbar)->
      navbar.html Mustache.render templates.BangNavbar, {}

    importCss: (root)->
      root.append("link").attr({rel: "stylesheet", href: chrome.extension.getURL('css/bootstrap.css'), type: "text/css"})
      root.append("link").attr({rel: "stylesheet", href: chrome.extension.getURL('css/bang.css'), type: "text/css"})
