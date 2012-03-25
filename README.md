


dry_haml_handlebars plugin
============

This gem may be of use to you if:

* angle brackets burn your eyes (read: you like using haml)
* you want to play with clientside MVC like backbone.js, spine.js or vertebral-column.js (I made the last one up, I think...)
* you need to render both client and server-side (so the googlebot and paranoid no-js people can see your lovely, lovely content)
* you prefer DRY apps to WET ones (i.e. you don't want to write two sets of templates)

Still here? Ok, this gem lets you:

* write haml views and partials for use server side (as per normal), but also...
* add them to your layouts as pre-compiled handlebars.js templates via a `template_include_tag`

You can send your app pre-rendered on the first call and then if your client-side framework successfully boots up (i.e. the client has javascript turned on), it can take over the rendering and add new content to the page (sent as JSON) using exactly the same templates. You never have to go near handlebars syntax (too many angle brackets), you just stick to haml, the way nature intended it. The only constraint is that you have to use the presenter pattern for your views (via the draper gem), but you were doing that already... right?

Installation
=======

Add this to your Gemfile if using Bundler: `gem 'dry_haml_handlebars'`

Or install the gem from the command line: `gem install dry_haml_handlebars`

Setup
=======

create a decorator using Draper as per usual:

* Run `rails g draper:install`
* Run `rails g draper:decorator your_model`

Edit `app/decorators/application_decorator.rb`, adding the following:

```
  include Haml::Helpers
  include Draper::HandlebarHelpers
```

Also, grab yourself a copy of [handlebars.runtime.js][1] and add it to your `application.js` manifest with:

```javascript
//= require handlebars.runtime`
```

Usage
=====

Suppose you have a view `app/views/articles/show.html.haml` that has been passed `@article` and `@comments` by the `ArticlesController`. These will be of type `ArticleDecorator` and `CommentDecorator`. An example view would be:

```haml
h1= @article['title']
.subtitle= @article['subtitle']
.author=   @article['author.fullname'] #NOTE: assume author is an association that points at a User model
.published_at= @article['published_at']
.controls
  = @article._if 'user.is_author'
    = @article.edit_button #NOTE: the clientside version of this view might have {{edit_url}} in the href attribute
.article-text= @article[['text']]
.comments
  render @comments
```

and a comments partial `app/views/articles/_comment.html.haml`:

```haml
h2= comment['author']
.posted_at= comment['posted_at']
.comment-text= comment['text']
```

Server-side rendering
---------------------

Note the use of the `decorated_model['some.method']` syntax. This is a special method added to the decorator (by `include Draper::HandlebarHelpers`). When rendering server-side, the corresponding decorator methods are called, e.g., `@article['title]` will call the `title` method of the `ArticleDecorator`, and add the article's title to the rendered html.

Client-side rendering
---------------------

We can also include these templates in our layout (`app/views/layouts/application.html.haml`) using:

```haml
= template_include_tag "/articles/article", "/articles/_comment"
```
This will add script tags, of type 'text/javascript', containing the compiled templates. In development mode it will also add script tags, of type 'text/x-handlebars-template', containing the uncompiled templates (CAUTION: contains angle brackets).

Using the developer tools on your browser, you can inspect the uncompiled templates and check your haml is getting converted correctly. You should see that the `decorated_model['some.method']` references have been replaced with mustache-wrapped versions. For example `@article['title']` will be `{{title}}`, and `@article[['text']]` (note the double square brackets) will have been converted to `{{{text}}}`, which is handlebars/mustache syntax for `html_safe`.

The precompiled templates automatically load themselves into `window.YourAppName.Templates`. You can render them by passing data like this:

```javascript
article_data = {title: "Hello World!", text: "&ltstrong&gtHello world!&lt/strong&gt is commonly used ..."};

view = MyBlogApp.Templates['/articles/article'](article_data);

$('article-wrapper').append(view);
```

Using handlebars conditionals like #if and #unless
--------------------------------------------------

More on this soon...

Writing decorator methods
-------------------------

More on this soon...

Acknowledgements
================

Thanks to the authors of:

* the poirot gem (I ripped off the asset handler)
* the handlebars gem (made server side compilation easy)
* the draper gem (made the presenter pattern easy)

Copyright (c) 2012 PeepAll Ltd, released under the MIT license

[1]: https://github.com/wycats/handlebars.js/downloads