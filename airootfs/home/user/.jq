def is_nullish(value):
  if value == null then
    true
  elif value | type == "string" then
    value | test("^ *$")
  else
    false
  end;

def spaces(width):
  (. | length) as $l | (width | tonumber) as $w |
    if $l < $w then "\(.)" + ($w - $l) * " " else . end;

def no_spaces:
  if is_nullish(.) | not then gsub("\\s+";"") else . end;

def trim:
  if is_nullish(.) | not then gsub("^\\s+ | \\s+$";"") else . end;

def uppercase:
  if is_nullish(.) | not then ascii_upcase else . end;

def downcase:
  if is_nullish(.) | not then ascii_downcase else . end;

def dft(value):
  if is_nullish(.) then value else . end;

def opt:
  if is_nullish(.) | not then . else "" end;

def lbl(display; default_value):
  dft(default_value) | (display + ":" | spaces($SPC)) + "\(.)";

def lbln(display; default_value):
  lbl(display; default_value) | "\(.)\n";

def lbl(display):
  lbl(display; "Unavailable");

def lbln(display):
  lbl(display) | "\(.)\n";

def olbl(display):
  if is_nullish(.) | not then
    lbl(display)
  else
    ""
  end;

def olbln(display):
  olbl(display) | if is_nullish(.) | not then "\(.)\n" else "" end;

def tree(display; default_value):
  if (is_nullish(.) | not) and (. | length > 0) then
    (display + ":" | spaces($SPC)) + "\(. | join("\n" + ($SPC|tonumber * " ")))"
  else
    (display + ":" | spaces($SPC)) + default_value
  end;

def treeln(display; default_value):
  tree(display; default_value) | "\(.)\n";

def tree(display):
  tree(display; "Unavailable");

def treeln(display):
  tree(display) | "\(.)\n";

def otree(display):
  if (is_nullish(.) | not) and (. | length > 0) then
    tree(display)
  else
    ""
  end;

def otreeln(display):
  otree(display) | if is_nullish(.) | not then "\(.)\n" else "" end;

def unit(value):
  if is_nullish(.) | not then "\(.)" + value else . end;

def enclose:
  if is_nullish(.) | not then "[\(.)]" else . end;

def append:
  if is_nullish(.) | not then " \(.)" else . end;

def ln:
  "\(.)\n";

def bool_to(truthy; falsy):
  if is_nullish(.) | not then
    if . then truthy else falsy end
  else
    .
  end;

def yes_no:
  bool_to("yes"; "no");

def up_down:
  bool_to("up"; "down");

def on_off:
  bool_to("on"; "off");
