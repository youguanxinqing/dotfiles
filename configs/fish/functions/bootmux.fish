function bootmux --description 'bootmux, falling back to the global default layout in directories without a project file'
    # 只接管裸 `bootmux start` / `bootmux stop`：一旦给了项目名或参数，
    # 就是用户自己点了菜，不要替他猜。目录自带 .tmuxinator.y[a]ml 时也走原路。
    if test (count $argv) -eq 1 && contains -- $argv[1] start s stop st \
        && not path is .tmuxinator.yml .tmuxinator.yaml
        # default.yaml 自己从 $PWD 取 root 和 session 名，这里不必传 settings。
        command bootmux $argv[1] default
    else
        command bootmux $argv
    end
end
