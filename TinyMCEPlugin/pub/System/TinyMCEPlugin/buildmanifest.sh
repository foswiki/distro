if test $# != 1; then echo ERROR: path to TMCE directory required; exit 1; fi
for i in $(find $1 -type f); 
do
    #i=${j/$1/};
    case $i in
    */build* )
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    */tools* ) 
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    */classes* )
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    */docs* )
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    */tests* )
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    *.psd )
    echo "#pub/System/TinyMCEPlugin/${i} 0644";
    ;; 
    *_src.* )
        echo pub/System/TinyMCEPlugin/${i} 0644;
        NOSRC=${i/_src}
        echo pub/System/TinyMCEPlugin/${NOSRC} 0644;
        echo pub/System/TinyMCEPlugin/${NOSRC}.gz 0644;
    ;;
    *.css )
        echo pub/System/TinyMCEPlugin/${i} 0644;
        echo pub/System/TinyMCEPlugin/${i}.gz 0644;
    ;;
    *.js )
        echo pub/System/TinyMCEPlugin/${i} 0644;
        echo pub/System/TinyMCEPlugin/${i}.gz 0644;
    ;;
    *) 
    echo pub/System/TinyMCEPlugin/${i} 0644;
    esac
done

