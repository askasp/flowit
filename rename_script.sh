TARGET_DIR=${1}
NEW_NAME_APP=${2}
NEW_NAME_OTP=${3}


# cd $TARGET_DIR
find $TARGET_DIR/ -type f -exec sed -i -e "s/Flowit/${NEW_NAME_APP}/g" {} \;
find $TARGET_DIR/ -type f -exec sed -i -e "s/flowit/${NEW_NAME_OTP}/g" {} \;
mv $TARGET_DIR/lib/flowit/ $TARGET_DIR/lib/${NEW_NAME_OTP}
mv $TARGET_DIR/lib/flowit_web $TARGET_DIR/lib/${NEW_NAME_OTP}

mv $TARGET_DIR/lib/flowit.ex $TARGET_DIR/lib/${NEW_NAME_OTP}.ex
mv $TARGET_DIR/lib/flowit_web.ex $TARGET_DIR/lib/${NEW_NAME_OTP}_web.ex


