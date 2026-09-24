{ vars }:
''
  general {
    hide_cursor = true
    grace = 0
  }
  background {
    monitor =
    path = ${vars.homeDirectory}/.local/state/current-lock-wallpaper
    blur_passes = 3
    blur_size = 8
    brightness = 0.38
    vibrancy = 0.18
  }
  animations {
    enabled = true
    bezier = orbit, 0.2, 0.8, 0.2, 1
    animation = fadeIn, 1, 3, orbit
    animation = fadeOut, 1, 2, orbit
  }
  shape {
    monitor =
    size = 220, 90
    color = rgba(00000000)
    border_color = rgba(72e7bc55)
    border_size = 1
    rounding = -1
    rotate = 28
    position = 0, 275
    halign = center
    valign = center
  }
  shape {
    monitor =
    size = 220, 90
    color = rgba(00000000)
    border_color = rgba(72e7bc55)
    border_size = 1
    rounding = -1
    rotate = -28
    position = 0, 275
    halign = center
    valign = center
  }
  shape {
    monitor =
    size = 76, 76
    color = rgba(112e27aa)
    border_color = rgba(9bffcf99)
    border_size = 2
    rounding = -1
    position = 0, 275
    halign = center
    valign = center
    shadow_passes = 3
    shadow_size = 20
    shadow_color = rgba(72e7bc44)
  }
  label {
    monitor =
    text = ✦
    color = rgba(cffff0ff)
    font_size = 34
    font_family = Sansation
    position = 0, 275
    halign = center
    valign = center
  }
  label {
    monitor =
    text = cmd[update:1000] date +'%H:%M'
    color = rgba(dffff0ff)
    font_size = 86
    font_family = Sansation Light
    position = 0, 135
    halign = center
    valign = center
  }
  label {
    monitor =
    text = cmd[update:60000] date +'%A, %d %B'
    color = rgba(9ce5c4ee)
    font_size = 24
    font_family = ForestSmooth
    position = 0, 45
    halign = center
    valign = center
  }
  label {
    monitor =
    text = ${vars.username}
    color = rgba(a5c9b8ff)
    font_size = 15
    font_family = Sansation
    position = 0, -18
    halign = center
    valign = center
  }
  input-field {
    monitor =
    size = 300, 56
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.5
    dots_center = true
    outer_color = rgba(72e7bc99)
    inner_color = rgba(0b241dc0)
    font_color = rgba(dffff0ff)
    font_family = Sansation
    fade_on_empty = false
    placeholder_text = Пароль
    rounding = 28
    check_color = rgba(b8ffdaff)
    fail_color = rgba(f0aa91ff)
    fail_text = Неверный пароль · $ATTEMPTS
    capslock_color = rgba(efd19aff)
    position = 0, -102
    halign = center
    valign = center
  }
  label {
    monitor =
    text = $LAYOUT
    color = rgba(9ce5c4ff)
    font_size = 14
    font_family = Sansation
    position = 0, -165
    halign = center
    valign = center
  }
''
