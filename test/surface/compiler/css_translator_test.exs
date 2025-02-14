defmodule Surface.Compiler.CSSTranslatorTest do
  use ExUnit.Case, async: true

  alias Surface.Compiler.CSSTranslator

  test "translate CSS" do
    css = """
    /* padding: s-bind(padding); */

    .root {
      --custom-color: s-bind('@css.background');
    }

    .a:has(> img) > b[class="btn"], c {
      padding: s-bind('@padding');
    }

    @media screen and (min-width: 1216px) {
      .blog{display:block;}
    }

    @tailwind utilities;
    """

    %{css: translated, selectors: selectors, vars: vars} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert selectors == %{
             elements: MapSet.new(["b", "c"]),
             classes: MapSet.new(["a", "blog", "root"]),
             ids: MapSet.new([]),
             other: MapSet.new([]),
             combined: MapSet.new([])
           }

    assert vars == %{
             "--029d26f" => {"@css.background", %{column: 25, column_end: 43, line: 4, line_end: 4}},
             "--c8f42e0" => {"@padding", %{column: 18, column_end: 29, line: 8, line_end: 8}}
           }

    assert translated == """
           /* padding: s-bind(padding); */

           .root[data-s-myscope] {
             --custom-color: var(--029d26f);
           }

           .a[data-s-myscope]:has(> img) > b[data-s-myscope][class="btn"], c[data-s-myscope] {
             padding: var(--c8f42e0);
           }

           @media screen and (min-width: 1216px) {
             .blog[data-s-myscope]{display:block;}
           }

           @tailwind utilities;
           """
  end

  test "translate selector with element, class and pseudo-class" do
    css = """
    div.blog:first-child { display: block }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           div[data-s-myscope].blog[data-s-myscope]:first-child { display: block }
           """

    assert selectors.elements == MapSet.new([])
    assert selectors.classes == MapSet.new([])
    assert selectors.combined == MapSet.new([MapSet.new([".blog", "div"])])
  end

  test "translate selector with pseudo-class with multiple arguments" do
    css = """
    :fake(div, 'whatever') {
      display: block;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           :fake(div, 'whatever') {
             display: block;
           }
           """

    assert selectors.elements == MapSet.new([])
    assert selectors.classes == MapSet.new([])
    assert selectors.combined == MapSet.new([])
  end

  test ":deep removes the scope when placed after the first selector" do
    css = """
    .a :deep(.b) {
      padding: 10px;
    }

    .c:deep(.d) {
      padding: 10px;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert selectors.classes == MapSet.new(["a", "c"])

    assert translated == """
           .a[data-s-myscope] .b {
             padding: 10px;
           }

           .c[data-s-myscope].d {
             padding: 10px;
           }
           """
  end

  test ":deep adds [data-s-self][data-s-xxxxxx] if it't the first selector" do
    css = """
    :deep(div > .link) {
      @apply hover:underline;
    }

    :deep(.a .link), :deep(.b .link) {
      @apply hover:underline;
    }

    :deep(.b).link, .c {
      @apply hover:underline;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           [data-s-self][data-s-myscope] div > .link {
             @apply hover:underline;
           }

           [data-s-self][data-s-myscope] .a .link, [data-s-self][data-s-myscope] .b .link {
             @apply hover:underline;
           }

           [data-s-self][data-s-myscope] .b.link[data-s-myscope], .c[data-s-myscope] {
             @apply hover:underline;
           }
           """

    assert selectors.elements == MapSet.new([])
    assert selectors.classes == MapSet.new(["c", "link"])
    assert selectors.ids == MapSet.new([])
    assert selectors.other == MapSet.new([])
    assert selectors.combined == MapSet.new([])
  end

  test ":global removes the scope of any selector" do
    css = """
    :global(.a) {
      padding: 10px;
    }

    :global(.b) .c {
      padding: 10px;
    }

    :global(.d).e {
      padding: 10px;
    }

    .a:global(.f) {
      padding: 10px;
    }

    :global(.g > .h) {
      padding: 10px;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert selectors.classes == MapSet.new(["a", "c", "e"])

    assert translated == """
           .a {
             padding: 10px;
           }

           .b .c[data-s-myscope] {
             padding: 10px;
           }

           .d.e[data-s-myscope] {
             padding: 10px;
           }

           .a[data-s-myscope].f {
             padding: 10px;
           }

           .g > .h {
             padding: 10px;
           }
           """
  end

  test "translate selector with multiple classes and pseudo-classes" do
    css = """
    .a[title="foo"]:first-child.b[title="bar"]:hover { display: block }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .a[data-s-myscope][title="foo"]:first-child.b[data-s-myscope][title="bar"]:hover { display: block }
           """

    assert selectors.classes == MapSet.new([])
    assert selectors.combined == MapSet.new([MapSet.new([".a", ".b"])])
  end

  test "translate selector with functions with multiple arguments" do
    css = """
    .test {
      margin: min(100px, 200px);
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .test[data-s-myscope] {
             margin: min(100px, 200px);
           }
           """

    assert selectors.classes == MapSet.new(["test"])
  end

  test "translate declaration with value containing commas" do
    css = """
    .Input [data-input] {
      font-feature-settings: 'case', 'cpsp' 0, 'dlig' 0, 'ccmp', 'kern';
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           .Input[data-s-myscope] [data-input] {
             font-feature-settings: 'case', 'cpsp' 0, 'dlig' 0, 'ccmp', 'kern';
           }
           """

    assert selectors.classes == MapSet.new(["Input"])
  end

  test "translate declaration with variants" do
    css = """
    a .external-link {
      padding: :theme(hover:underline);
      @apply hover:underline;
      @apply bg-sky-500 hover:bg-sky-700;
      @apply lg:[&:nth-child(3)]:hover:underline;
      @apply [&_p]:mt-4;
    }
    """

    %{css: translated, selectors: selectors} = CSSTranslator.translate!(css, scope_id: "myscope")

    assert translated == """
           a[data-s-myscope] .external-link[data-s-myscope] {
             padding: :theme(hover:underline);
             @apply hover:underline;
             @apply bg-sky-500 hover:bg-sky-700;
             @apply lg:[&:nth-child(3)]:hover:underline;
             @apply [&_p]:mt-4;
           }
           """

    assert selectors.elements == MapSet.new(["a"])
    assert selectors.classes == MapSet.new(["external-link"])
  end
end
