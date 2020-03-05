/// CheckCell(x1, y1, x2, y2, alpha, doitCliquer)

var alpha=argument4;
var doitCliquer=argument5;

argument1--;
argument3--;

if xmouse>=argument0
if ymouse>=argument1
if xmouse<=argument2
if ymouse<=argument3 {
    var oldAlp=draw_get_alpha();
    draw_set_alpha(alpha);
    draw_set_color(c_white);
    draw_rectangle(argument0, argument1, argument2, argument3, 0);
    draw_set_alpha(oldAlp);
    if not doitCliquer
        return 1;
    
    if doitCliquer and mouse_check_button_pressed(mb_left)
        return 1;
}

return 0;
