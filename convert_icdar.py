import os
import cv2
import argparse
import numpy
import glob
import numpy as np

ICDAR_ANNOTATED_EXT = ".txt"
TESS_ANNOTATED_EXT = ".gt.txt"
TESS_IMAGE_EXT = ".tif"
PADDING = 5

def convert_icdar(input_folder, output_folder, extends=["jpg", "png", "jpeg", "JPG"]):
    image_names = []
    for ext in extends:
        image_names.extend(glob.glob(
            os.path.join(input_folder, '*.{}'.format(ext))))
    for image_name in image_names:
        annotation_name = image_name.split(".")[0]+ICDAR_ANNOTATED_EXT
        image = cv2.imread(image_name)
        annotation = [line.replace("\ufeff", "").split(",") for line in 
                      open(annotation_name, "r").readlines()]
        print("\r"+image_name, sep="", end="", flush=True)
        ite = 0
        for box_line in annotation:
            if len(box_line) < 9 or len(",".join(box_line[8:])) <= 1:
                continue
            box = np.array([[int(box_line[i]), int(box_line[i+1])] for i in range(0, 8, 2)])
            box[0, :] -= PADDING
            box[1, 0] += PADDING
            box[1, 1] -= PADDING
            box[2, :] += PADDING
            box[3, 0] -= PADDING
            box[3, 1] += PADDING
            # normalize text box 
            w = np.linalg.norm(box[0]-box[1])
            h = np.linalg.norm(box[0]-box[3])
            pts1 = box.astype(np.float32)
            pts2 = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
            M = cv2.getPerspectiveTransform(pts1, pts2)
            sub_image = cv2.warpPerspective(image, M, (int(w), int(h)))
            sub_image_name = os.path.join(
                output_folder, os.path.basename(image_name).split(".")[0]+"_"+str(ite))
            cv2.imwrite(sub_image_name+TESS_IMAGE_EXT, sub_image)
            with open(sub_image_name+TESS_ANNOTATED_EXT, "w") as out_file:
                out_file.write(",".join(box_line[8:]))
            ite += 1
    print("\nProcess done.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Converter from ICDAR dataset to Tesseract dataset')
    parser.add_argument('-i', '--input_folder', metavar='input', type=str)
    parser.add_argument('-o', '--output_folder', metavar='output', type=str)
    args = parser.parse_args()
    convert_icdar(args.input_folder, args.output_folder)