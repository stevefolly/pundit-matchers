# Pundit Matchers

[![Gem Version][version-badge]][rubygems]
[![Test][github-actions-test-badge]][github-actions-test]
[![RuboCop][github-actions-rubocop-badge]][github-actions-rubocop]

A set of RSpec matchers for testing [Pundit][pundit-github]
authorisation policies. The matcher syntax was inspired by
[this excellent blog post][thunderbolt-labs] from Thunderbolt Labs.

## Installation

Include `pundit-matchers` in your Rails application's Gemfile, inside the test
group:

```ruby
group :test do
  gem 'pundit-matchers', '~> 3.1'
end
```

And then execute the following command:

`bundle`

Pundit Matchers expects that the application you're testing is using a
software stack consisting of:

- Ruby 3+
- Pundit 2+
- RSpec 3.12+

## Setup

Add the following to the top of your Rails application's `spec/spec_helper.rb`
file:

`require 'pundit/matchers'`

## Configuration

Pundit Matchers relies on your policies having a `user` attribute. If your app
checks against a differently named "user" model (such as `account`) you will
need to set a user alias. To add a user alias, add the following configuration
to your app's `spec/spec_helper.rb` or `spec/rails_helper.rb` file:

```ruby
Pundit::Matchers.configure do |config|
  # Change the default user alias
  config.default_user_alias = :account

  # Change the user alias for a specific policy
  config.user_aliases = { 'Post' => :account }
end
```

## Matchers

The following RSpec matchers can now be used in your Pundit policy spec
files (by convention, saved in the `spec/policies` directory).

### Permit Matchers

- `permit_only_actions(%i[action1 action2])` Tests that an array of actions,
  passed in as a parameter, are the only actions permitted by the policy.
- `permit_all_actions` Tests that all actions in the policy are permitted.
- `permit_action(:action_name)` Tests that an action, passed in as a parameter,
  is permitted by the policy.
- `permit_actions(%i[action1 action2])` Tests that an array of actions, passed
  in as a parameter, are permitted by the policy.
- `permit_new_and_create_actions` Tests that both the new and create actions
  are permitted by the policy.
- `permit_edit_and_update_actions` Tests that both the edit and update actions
  are permitted by the policy.
- `permit_attribute` Tests that an attribute, passed in as a parameter,
  is permitted by the policy for mass assignment.
- `permit_attributes` Tests that a list of attributes, passed in as a parameter,
  are permitted by the policy for mass assignment.
- `permit_mass_assignment_of` Alternative syntax for `permit_attributes`, used
  for backward compatibility with older test suites.

### Forbid Matchers

- `forbid_only_actions(%i[action1 action2])` Tests that an array of actions,
  passed in as a parameter, are the only actions forbidden by the policy.
- `forbid_all_actions` Tests that all actions in the policy are forbidden.
- `forbid_action(:action_name)` Tests that an action, passed in as a parameter,
  is not permitted by the policy.
- `forbid_actions(%i[action1 action2])` Tests that an array of actions, passed
  in as a parameter, are not permitted by the policy.
- `forbid_new_and_create_actions` Tests that both the new and create actions
  are not permitted by the policy.
- `forbid_edit_and_update_actions` Tests that both the edit and update actions
  are not permitted by the policy.
- `forbid_attribute` Tests that an attribute, passed in as a parameter,
  is not permitted by the policy for mass assignment.
- `forbid_attributes` Tests that a list of attributes, passed in as a parameter,
  are not permitted by the policy for mass assignment.
- `forbid_mass_assignment_of` Alternative syntax for `forbid_attributes`, used
  for backward compatibility with older test suites.

## A Basic Example of a Policy Spec

The following example shows how to structure a Pundit policy spec (in this
example, the spec would be located in `spec/policies/article_policy_spec.rb`)
which authorises administrators to view and manage articles, while visitors
are only authorised to have read only access.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_only_actions(%i[index show]) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_all_actions }
  end
end
```

## A Testing Strategy

Pundit Matchers makes several assumptions about how you're going to structure
your policy spec file. First, you should declare a subject for the spec. The
subject should be a new instance of the policy class that you're testing. For
example:

```ruby
subject { described_class.new(user, article) }
```

The subject will be implicitly referenced inside of `it` blocks throughout the
spec, whenever a permit or forbid matcher is used. The new method of the policy
class should also contain the two objects that will be used to authorise each
action within the policy: the user who is attempting access to the record and
the record which is to be authorised.

Throughout the spec, you can use `let` statements to create objects for the
user/record pair which is being authorised. For example, the following
`permit_action` matcher would test that the user can destroy articles
containing a `user_id` attribute which matches the user's ID:

```ruby
let(:user) { User.create }
let(:article) { Article.new(user_id: user.id) }

it { is_expected.to permit_action(:destroy) }
```

The user and record objects used by the subject policy class will be
reassigned whenever you reassign these using the `let` keyword. This will
typically be done on a per context basis, as you will likely want to check the
outcome of an authorisation attempt using different configurations of
user/record pairs based on application state. These variations should be
organised into separate RSpec context blocks, as in the previous example.

## Testing For an Allow List of Permitted Actions

As of Pundit Matchers 2.1, the recommended approach is to use an explicit
allow list of actions permitted by the policy (`permit_only_actions`) which
will cause the test to fail if other actions in the policy are not forbidden.

Using allow lists ensures for comprehensiveness so that any actions that
shouldn't be permitted don't slip through the cracks in practice, for example
due to developer oversight. The [OWASP Top 10 - 2021][owasp-top-10] recommends
that access control enforces policy so that users cannot act outside of their
intended permissions. It was discovered that 94% of applications that were
tested had some form of [broken access control][broken-access-control] with an
average incidence rate of 3.81%.

The following example tests a policy that authorises visitors to view articles
only, while administrators can create and update articles (but are forbidden
from deleting them):

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_only_actions(%i[index show]) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_only_actions(%i[index show new create edit update]) }
  end
end
```

This approach would be robust in the following scenario:

- `ArticlePolicy` is created with `index`, `create`, and `destroy` actions.
- The policy is tested with `permit_only_actions(%i[index create destroy])`
- After several months, a developer adds a `publish` action, which would
  automatically be tested to be forbidden since it is not in the allow list of
  permitted actions.

The opposite approach is to test for the only actions that are forbidden with
the `forbid_only_actions` matcher:

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to forbid_only_actions(%i[new create edit update destroy]) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to forbid_only_actions(%i[destroy]) }
  end
end
```

You can use both `permit_only_actions` and `forbid_only_actions` in the same
context. However, this approach would test the policy twice. In terms of minimum
clearance, using just the `permit_only_actions` matcher would be sufficient.
The other advantage with `permit_only_actions` is that it does require knowledge
of the whole policy.

## Testing All Actions

In some cases, the allow list of permitted or forbidden actions will encompass
all of the actions in the policy. As a shorthand, the `permit_all_actions` and
`forbid_all_actions` matchers are also available. If all actions for a policy
are expected to be permitted or forbidden you can write a single expectation
that will check every action in the policy.

```ruby
RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

   context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to forbid_all_actions }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_all_actions }
  end
end
```

## Testing a Single Action

While it is recommended to use `permit_only_actions`, sometimes you may want to
test that a single action is authorised without testing other actions in the
policy. This may be because you are only concerned about testing a particular
context, for example testing whether a user can publish an article:

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:user) { User.create }

  context 'when user updates an article that they authored' do
    let(:article) { Article.create(user_id: user.id) }

    it { is_expected.to permit_action(:update) }
  end

  context 'when user updates an article that they did not author' do
    let(:article) { Article.create(user_id: nil) }

    it { is_expected.to forbid_action(:update) }
  end
end
```

## Testing Multiple Actions

To test multiple actions at once the `permit_actions` and `forbid_actions`
matchers can be used. Both matchers accept an array of actions as a parameter.

While it is recommended to use `permit_only_actions` over these more permissive
matchers, they are useful for documenting the intent for a particular context;
if you use the `forbid_actions` matchers it is a good idea to test using
`permit_only_actions` matchers in addition to it for comprehensiveness.

In the following example, visitors can view articles, while administrators
can also manage (but not delete) articles.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_only_actions(%i[index show]) }
    it { is_expected.to forbid_actions(%i[create update destroy]) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_only_actions(%i[index show new create edit update]) }
    it { is_expected.to forbid_actions(%i[destroy]) }
  end
end
```

Optionally, you can pass the actions to the `permit_actions` and
`forbid_actions` matchers as a series of parameters, rather than an array. The
following examples are equivalent:

```ruby
it { is_expected.to forbid_actions([:show, :create, :update]) }
it { is_expected.to forbid_actions(%i[show create update]) }
it { is_expected.to forbid_actions(:show, :create, :update) }
```

## Testing New/Create and Edit/Update Pairs

It common to write separate authorisation policies on a per action basis. A
notable exception to this is in the case of new/create and edit/update action
pairs. Generally speaking, you do not want to allow users to access a 'new'
form unless the user is also authorised to create the record associated with
that form. Similarly, you generally do not want the user to access an 'edit'
form unless that user can also update the associated record.

Pundit Matchers provides four shortcut matchers to account for these common
scenarios:

- `permit_new_and_create_actions`
- `permit_edit_and_update_actions`
- `forbid_new_and_create_actions`
- `forbid_edit_and_update_actions`

The following example tests a policy which grants administrators permission to
create articles, but does not authorise visitors to do the same.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to forbid_new_and_create_actions }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_new_and_create_actions }
  end
end
```

## Testing if an Attribute is Authorised

For policies that contain a `permitted_attributes` method (to authorise only
particular attributes), Pundit Matchers provides two matchers to test for mass
assignment.

- `permit_attribute(:attribute_name)`
- `forbid_attribute(:attribute_name)`

Let's modify the earlier example which tests a policy where administrators are
granted permission to create articles, but visitors are not authorised to do so.
In this updated example, visitors _can_ create articles but they cannot set the
publish flag.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_new_and_create_actions }
    it { is_expected.to forbid_attribute(:publish) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_new_and_create_actions }
    it { is_expected.to permit_attribute(:publish) }
  end
end
```

## Testing if Multiple Attributes are Authorised

To test multiple attributes at once, the `permit_attributes` and
`forbid_attributes` matchers can be used. Both matchers accept single,
multiple, arrays and hashes of attributes as a parameter. In the following
example, visitors can only set the name of articles, while administrators
can also set the description.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_attribute(:name) }
    it { is_expected.to forbid_attribute(:description) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_attributes(%i[name description]) }
  end
end
```

Just like `permit_actions` and `forbid_actions`, you can pass the attributes
to check as a series of parameters, rather than an array.

The following examples are equivalent:

```ruby
it { is_expected.to permit_attributes([:first_name, :last_name]) }
it { is_expected.to permit_attributes(%i[first_name last_name]) }
it { is_expected.to permit_attributes(:first_name, :last_name) }
it { is_expected.to permit_mass_assignment_of(:first_name, :last_name) }
```

### Testing Nested Attributes

It is possible to test nested attributes by specifying them with the usual
nested syntax:

```ruby
it 'permits nested attributes for address' do
  is_expected.to(
    permit_attribute(address_attributes: [:country])
  )
end
```

There is no limit to the depth of nested attributes, allowing for testing at
any necessary level.

## Testing if Attributes are Authorised for Particular Actions

Pundit allows you to permit different attributes based on the current action
by adding a `permitted_attributes_for_#{action}` method to your policy.
Pundit Matchers supports testing of these methods via composable matchers.

- `permit_attribute(:attribute_name).for_action(:action_name)`
- `forbid_attribute(:attribute_name).for_action(:action_name)`

To illustrate this, we'll check for the mass assignment of a slug attribute in
our spec. The policy is expected to allow visitors to set the slug attribute
when creating an article, but not when updating it. Administrators will be
permitted to set the slug when either creating or updating the article.

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:article) { Article.new }

  context 'with visitors' do
    let(:user) { nil }

    it { is_expected.to permit_only_actions(%i[new create edit update]) }
    it { is_expected.to forbid_attribute(:slug) }
    it { is_expected.to permit_attribute(:slug).for_action(:create) }
    it { is_expected.to forbid_attribute(:slug).for_action(:update) }
  end

  context 'with administrators' do
    let(:user) { User.new(administrator: true) }

    it { is_expected.to permit_only_actions(%i[new create edit update]) }
    it { is_expected.to permit_attribute(:slug) }
    it { is_expected.to permit_attribute(:slug).for_action(:create) }
    it { is_expected.to permit_attribute(:slug).for_action(:update) }
  end
end
```

Warning: Currently, Pundit Matchers does _not_ automatically check if the
attribute is permitted by a `permitted_attributes_for_#{action}` method, so even
if you include a `forbid_attribute(:attribute)` expectation in the
policy spec, it's entirely possible that the attribute _is_ being permitted
through a `permitted_attributes_for_#{action}` method that is tested separately.
For this reason, you should always explicitly test _all_ implemented
`permitted_attributes_for_#{action}` methods, as demonstrated in the example.

## Testing Resolved Scopes

Another common scenario is to authorise particular records to be returned
in a collection, based on particular properties of candidate records for that
collection. To test for this you don't need to use any matchers. Instead, you
can test for the inclusion or exclusion of a record in the resolved scope by
using the `let` keyword to create a resolved scope based on the current user
and record objects used by a `Policy::Scope` class.

For example, to test that visitors can only view published articles in
a resolved scope you could write your policy spec as follows:

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:resolved_scope) do
    described_class::Scope.new(user, Article.all).resolve
  end

  let(:user) { nil }

  context 'when visitor accesses a published article' do
    let(:article) { Article.create(publish: true) }

    it 'includes article in resolved scope' do
      expect(resolved_scope).to include(article)
    end
  end

  context 'when visitor accesses an unpublished article' do
    let(:article) { Article.create(publish: false) }

    it 'excludes article from resolved scope' do
      expect(resolved_scope).not_to include(article)
    end
  end
end
```

## Putting It All Together

The following example puts all of the techniques discussed so far together in
one policy spec that tests multiple user and record configurations within
different context blocks. Here visitors can view published articles and create
unpublished articles, while administrators have full access to all articles.
Visitors can only set the slug attribute when creating an article.

To avoid deeply nested context trees it is a good idea to split larger policy
specs up into multiple files. Here we divide the policy spec into seperate files
for the visitor and administrator contexts, but you could just as easily split
the files by published status or policy action.

`spec/policies/article_policy/visitor_context_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:resolved_scope) do
    described_class::Scope.new(user, Article.all).resolve
  end

  let(:user) { nil }

  context 'when visitor creates a new article' do
    let(:article) { Article.new }

    it { is_expected.to permit_new_and_create_actions }
  end

  context 'when visitor accesses a published article' do
    let(:article) { Article.create(publish: true) }

    it 'includes article in resolved scope' do
      expect(resolved_scope).to include(article)
    end

    it { is_expected.to permit_only_actions(%i[index show]) }
  end

  context 'when visitor accesses an unpublished article' do
    let(:article) { Article.create(publish: false) }

    it 'excludes article from resolved scope' do
      expect(resolved_scope).not_to include(article)
    end

    it { is_expected.to forbid_all_actions }
  end

  describe 'permitted attributes for visitor' do
    it { is_expected.to forbid_attribute(:publish) }
    it do
      is_expected.to forbid_attribute(:publish).for_action(:create)
    end
    it do
      is_expected.to forbid_attribute(:publish).for_action(:update)
    end
    it { is_expected.to forbid_attribute(:slug) }
    it { is_expected.to permit_attribute(:slug).for_action(:create) }
    it { is_expected.to forbid_attribute(:slug).for_action(:update) }
  end
end
```

`spec/policies/article_policy/administrator_context_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ArticlePolicy do
  subject { described_class.new(user, article) }

  let(:resolved_scope) do
    described_class::Scope.new(user, Article.all).resolve
  end

  let(:user) { User.new(administrator: true) }

  context 'when administrator creates a new article' do
    let(:article) { Article.new }

    it { is_expected.to permit_new_and_create_actions }
  end

  context 'when administrator accesses a published article' do
    let(:article) { Article.create(publish: true) }

    it 'includes article in resolved scope' do
      expect(resolved_scope).to include(article)
    end

    it { is_expected.to permit_all_actions }
  end

  context 'when administrator accesses an unpublished article' do
    let(:article) { Article.create(publish: false) }

    it 'includes article in resolved scope' do
      expect(resolved_scope).to include(article)
    end

    it { is_expected.to permit_all_actions }
  end

  describe 'permitted attributes for administrator' do
    it { is_expected.to permit_attribute(:publish) }
    it do
      is_expected.to permit_attribute(:publish).for_action(:create)
    end
    it do
      is_expected.to permit_attribute(:publish).for_action(:update)
    end
    it { is_expected.to permit_attribute(:slug) }
    it { is_expected.to permit_attribute(:slug).for_action(:create) }
    it { is_expected.to permit_attribute(:slug).for_action(:update) }
  end
end
```

The advantage of this approach is that it increases the readability of your
specs. It allows you to place all of your specifications for authorising a
particular context (user and record configuration) inside of a single context
block, with each spec file representing a wider context.

## Development

Run RSpec: `docker build . && docker-compose run lib bin/rspec`

Run Rubocop: `docker build . && docker-compose run lib bin/rubocop`

## Contributing

- Use the [Ruby Style Guide][ruby-style-guide].
- Run `bin/rubocop` before submitting a pull request with the aim of not
  introducing any new Rubocop violations.

[version-badge]: https://img.shields.io/gem/v/pundit-matchers.svg
[rubygems]: https://rubygems.org/gems/pundit-matchers
[github-actions-test]: https://github.com/pundit-community/pundit-matchers/actions/workflows/test.yml
[github-actions-test-badge]: https://github.com/pundit-community/pundit-matchers/actions/workflows/test.yml/badge.svg
[github-actions-rubocop]: https://github.com/pundit-community/pundit-matchers/actions/workflows/rubocop.yml
[github-actions-rubocop-badge]: https://github.com/pundit-community/pundit-matchers/actions/workflows/rubocop.yml/badge.svg
[pundit-github]: https://github.com/varvet/pundit
[thunderbolt-labs]: https://www.thunderboltlabs.com/blog/2013/03/27/testing-pundit-policies-with-rspec/
[owasp-top-10]: https://owasp.org/Top10/
[broken-access-control]: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
[ruby-style-guide]: https://github.com/bbatsov/ruby-style-guide
