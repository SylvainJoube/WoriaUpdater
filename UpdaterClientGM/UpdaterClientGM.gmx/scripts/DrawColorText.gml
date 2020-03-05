/// DrawColorText(x, y, texte, couleur);
var col = draw_get_color();
var alp = draw_get_alpha()
draw_set_color(c_black);
draw_set_alpha(0.8*alp);
draw_text(argument0+1, argument1+1, argument2);
draw_set_color(argument3);
draw_set_alpha(1*alp);
draw_text(argument0, argument1, argument2);
draw_set_color(col);
draw_set_alpha(alp);
