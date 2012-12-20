**NOTE** this gem is work in progress, I'll flesh out the instructions once it's stabilized

dry_haml_handlebars plugin
============

This gem may be of use to you if:

* angle brackets burn your eyes (read: you like using haml)
  * NOTE: if you're fine with angle brackets, stop reading, you're probably better off just using mustache
  * see http://railscasts.com/episodes/295-sharing-mustache-templates
* you want your app to consume its own API and do most rendering clientside (e.g. using backbone.js, spine.js etc.)
* but you still need to render server-side (so the googlebot and paranoid no-js people can see your lovely, lovely content)
* and, importantly, you prefer DRY apps to WET ones (i.e. you don't want to write equivalent clientside and serverside templates)

Still here? Ok, this gem lets you:

* write templates using a haml/handlebars.js hybrid
* the haml describes the structure of the document while the handlebars syntax is used for substitution and logical flow
* it assumes you are using the rabl gem to generate JSON data for your view

What it does is:

* convert your hybrid templates to valid haml in which the handlebars markup is just treated as text
* then runs that through the standard haml handler to generate regular handlebars templates (html + curly braces)
* when rendering serverside it uses execjs and your rabl-generated JSON to render the template
* but it also ships pre-compiled versions of your templates and JSON data to the client (using the gon gem) so that you can switch to clientside rendering for subsequent requests

Installation
=======

Add this to your Gemfile if using Bundler: `gem 'dry_haml_handlebars'`

Or install the gem from the command line: `gem install dry_haml_handlebars`

Setup
=======

Usage
=====

Hybrid haml/handlebars syntax
-----------------------------

The syntax for your templates is a readable mix of haml and handlebars:

```haml
.entry
  .h1 {{title}}
  {{#if subtitle}}
    .h2 {{subtitle}}
  {{/if}}
  .h3 By
    = link_to "{{author.name}}", user_path("{{author.id}}"), 'data-remote' => true
  posted at {{localize created_at}}
  .body
    {{{body}}}
```

Benefits:

* the brevity and structural clarity that haml provides
* the ability to use standard rails helpers to generate html
* concise flow constrol and substitution via handlebars
* the ability to use custom handlebars helpers (e.g. localize)
* seamless integration with your JSON API - structure the JSON (via rabl), then structure the view around it

*more to follow...*

Acknowledgements
================

Thanks to the authors of:

* the handlebars gem (made server side compilation easy)

Copyright (c) 2012 PeepAll Ltd, released under the MIT license